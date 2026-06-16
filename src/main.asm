%include "./include/header.inc"

section .text
    global _start

_start:
    mov r13, rsp                                       ; Save stack pointer (rsp) to r13
    call _args_handler                                 ; Process command-line arguments

.exit_ok:
    syscall_exit 0                                     ; Exit program with status 0

.exit_err:
    syscall_exit 1                                     ; Exit program with status 1

_args_handler:
    cmp qword [r13], 2                                 ; Check if argc < 2
    jl _arg_executor.handle_noarg                      ; Branch if no arguments provided
    mov r14, 16                                        ; Initial offset for argv[1]
    mov r12, [r13 + r14]                               ; Load argv[1] address into r12
    mov r15, 1                                         ; Initialize loop counter (r15 = 1)
    jmp .args_loop                                     ; Enter argument processing loop
    jmp _start.exit_ok                                 ; Fallback exit (unreachable)

.args_loop:
    cmp r15, [r13]                                     ; Check if all arguments processed (r15 == argc)
    je .done_args                                      ; Exit loop if finished
    call _arglen_counter                               ; Calculate length of current argument
    call _arg_executor                                 ; Execute current argument handler
    inc r15                                            ; Increment loop counter
    add r14, 8                                         ; Move to next argv element
    mov r12, [r13 + r14]                               ; Load next argument address
    jmp .args_loop                                     ; Repeat loop

.done_args:
    call _list_dir                                     ; List target directory contents
    ret                                                ; Return to caller

_arg_executor:
.handler_selector:
    cmp r9, 2                                          ; Check if argument length <= 2
    jle .handle_sarg                                   ; Handle as short option (-x)
    jmp .handle_larg                                   ; Handle as long option (--xxx)

.done_executor:
    mov [rel fpath], r12                               ; Store argument as target file path
    ret                                                ; Return to caller

.handle_noarg:
    call _list_dir                                     ; List current working directory
    jmp _start.exit_ok                                 ; Exit program successfully

.handle_sarg:
    callmatch_sarg help_arg, .print_help               ; Match short help option
    callmatch_sarg ver_arg, .print_ver                 ; Match short version option
    callmatch_sarg sec_arg, .set_sec                   ; Match short secret option
    jmp .exit_executor                                 ; Proceed to exit validation

.handle_larg:
    callmatch_larg help_arg, help_arglen, .print_help  ; Match long help option
    callmatch_larg ver_arg, ver_arglen, .print_ver     ; Match long version option
    callmatch_larg sec_arg, sec_arglen, .set_sec       ; Match long secret option
    jmp .exit_executor                                 ; Proceed to exit validation

.exit_executor:
    mov al, byte [r12]                                 ; Load first character of argument
    cmp al, hyphen_min                                 ; Check if it starts with '-'
    je .print_argerr                                   ; Branch if it is an invalid option
    jmp .done_executor                                 ; Save as path if it is a positional argument

.set_sec:
    mov byte [rel show_sec], 1                         ; Enable show_sec flag (true)
    ret                                                ; Return to caller

.print_ver:
    syscall_print ver_msg, ver_msglen                  ; Print version message
    jmp _start.exit_ok                                 ; Exit program successfully

.print_help:
    syscall_print help_msg, help_msglen                ; Print help message
    jmp _start.exit_ok                                 ; Exit program successfully

.print_argerr:
    syscall_print err_msg, err_msglen                  ; Print error prefix message
    syscall_println r12, r9                            ; Print invalid argument string
    jmp _start.exit_err                                ; Exit program with error status

_arglen_counter:
    xor r9, r9                                         ; Initialize character counter to 0

.count_arglen:
    cmp byte [r12 + r9], 0                             ; Check for null terminator (0x00)
    je .end_counter                                    ; Exit loop if null terminator found
    inc r9                                             ; Increment character count
    jmp .count_arglen                                  ; Repeat length check loop

.end_counter:
    ret                                                ; Return to caller

_compare_arg:
    xor rcx, rcx                                       ; Initialize index pointer to 0

.compare_argloop:
    mov al, byte [r12 + rcx]                           ; Load byte from input argument
    mov bl, byte [rdi + rcx]                           ; Load byte from target option
    cmp al, bl                                         ; Compare characters
    jne .arg_notequal                                  ; Branch if characters mismatch
    cmp al, 0                                          ; Check for null terminator
    je .arg_equal                                      ; Branch if strings match completely
    inc rcx                                            ; Move to next character index
    jmp .compare_argloop                               ; Repeat comparison loop

.arg_notequal:
    mov rax, 0                                         ; Return 0 (false)
    ret                                                ; Return to caller

.arg_equal:   
    mov rax, 1                                         ; Return 1 (true)
    ret                                                ; Return to caller

_list_dir:
    mov rax, sys_openat                                ; Invoke sys_openat syscall
    mov rdi, at_fdcwd                                  ; Use current working directory FD
    mov rsi, [rel fpath]                               ; Target path parameter
    mov rdx, o_readonly                                ; Read-only flag parameter
    mov r10, 0                                         ; Mode parameter (ignored for read-only)
    syscall                                            ; Execute syscall

    cmp rax, 0                                         ; Check openat return value
    jl .open_error                                     ; Branch if syscall failed (rax < 0)
    mov [rel fd_dir], rax                              ; Store directory file descriptor

.read_loop:
    mov rax, sys_getdents64                            ; Invoke sys_getdents64 syscall
    mov rdi, [rel fd_dir]                              ; Directory file descriptor parameter
    mov rsi, dir_buff                                  ; Buffer pointer parameter
    mov rdx, buff_size                                 ; Buffer size parameter (4KB)
    syscall                                            ; Execute syscall

    cmp rax, 0                                         ; Check getdents64 return value
    je .close_dir                                      ; End of directory reached (rax == 0)
    jl .read_error                                     ; Branch if syscall failed (rax < 0)
    mov rbx, rax                                       ; Store total bytes read in rbx
    xor rcx, rcx                                       ; Reset buffer offset index to 0

.parse_entries:
    cmp rcx, rbx                                       ; Check if buffer fully parsed (offset >= bytes read)
    jge .read_loop                                     ; Fetch next block of entries
    lea rdx, [dir_buff + rcx]                          ; Calculate current entry address
    movzx r8, word [rdx + 16]                          ; Load d_reclen (entry record length)
    lea rsi, [rdx + 19]                                ; Load d_name (filename string address)
    cmp byte [rsi], period_dot                         ; Check if filename starts with '.'
    jne .not_hidden                                    ; Process if it is a regular entry
    cmp byte [rel show_sec], 1                         ; Check if show hidden files flag is enabled
    je .not_hidden                                     ; Process if flag is true
    jmp .skip_entry                                    ; Skip entry if hidden and flag is false

.not_hidden:
    xor r9, r9                                         ; Initialize name length counter to 0

.count_namelen:
    cmp byte [rsi + r9], null_term                     ; Check for null terminator in filename
    je .print_name                                     ; Branch if end of string reached
    inc r9                                             ; Increment name length count
    jmp .count_namelen                                 ; Repeat name length loop

.print_name:
    push rbx                                           ; Preserve rbx register
    push rcx                                           ; Preserve rcx register
    push r8                                            ; Preserve r8 register
    push r9                                            ; Preserve r9 register
    syscall_println rsi, r9                            ; Print entry name to stdout
    pop r9                                             ; Restore r9 register
    pop r8                                             ; Restore r8 register
    pop rcx                                            ; Restore rcx register
    pop rbx                                            ; Restore rbx register

.skip_entry:
    add rcx, r8                                        ; Advance offset to next entry (rcx += d_reclen)
    jmp .parse_entries                                 ; Process next entry

.close_dir:
    mov rax, sys_close                                 ; Invoke sys_close syscall
    mov rdi, [rel fd_dir]                              ; File descriptor parameter
    syscall                                            ; Execute syscall
    ret                                                ; Return to caller

.open_error:
    syscall_print oerr_msg, oerr_len                   ; Print directory open error message
    jmp _start.exit_err                                ; Exit program with error status

.read_error:
    syscall_print rerr_msg, rerr_len                   ; Print directory read error message
    jmp _start.exit_err                                ; Exit program with error status