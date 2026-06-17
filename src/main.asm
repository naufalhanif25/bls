%include "./include/header.inc"

section .text
    global _start

_start:
    mov r13, rsp                                                   ; Save stack pointer (rsp) to r13
    call _args_handler                                             ; Process command-line arguments

.exit_ok:
    syscall_exit 0                                                 ; Exit program with status 0

.exit_err:
    syscall_exit 1                                                 ; Exit program with status 1

_args_handler:
    mov rbx, [r13]                                                 ; Load argc into rbx
    cmp rbx, 1                                                     ; Check if argc <= 1 (only program name)
    jle _arg_executor.handle_noarg                                 ; Branch if no arguments provided
    mov r14, 8                                                     ; Offset untuk argv (dimulai dari argv[1])
    mov r15, 1                                                     ; Initialize loop counter (r15 = 1)

.args_loop:
    cmp r15, [r13]                                                 ; Check if r15 == argc
    jge .done_args                                                 ; Exit loop if finished
    add r14, 8                                                     ; Advance to next argv element offset
    mov r12, [r13 + r14]                                           ; Load next argument address into r12
    test r12, r12                                                  ; Safety check: is string null?
    jz .done_args                                                  ; Exit loop if null pointer encountered
    call _arglen_counter                                           ; Calculate length of current argument (stored in r9)
    call _arg_executor                                             ; Execute current argument handler
    inc r15                                                        ; Increment loop counter
    jmp .args_loop                                                 ; Repeat loop

.done_args:
    call _list_dir                                                 ; List target directory contents
    ret                                                            ; Return to caller

_arg_executor:
.handler_selector:
    mov al, [r12]                                                  ; Load first character of the argument string
    cmp al, hyphen_min                                             ; Check if starts with '-'
    jne .handle_ls                                                 ; If not, treat as path string
    mov al, [r12 + 1]                                              ; Load second character of the argument string
    cmp al, hyphen_min                                             ; Check if it is '--'
    je .handle_larg                                                ; Branch to long option handler if true
    jmp _handle_sargs                                              ; Else, process as cluster of short args

.handle_ls:
    mov [rel fpath], r12                                           ; Store argument as target file path
    ret                                                            ; Return to caller

.handle_noarg:
    call _list_dir                                                 ; List current working directory
    jmp _start.exit_ok                                             ; Exit program successfully

.handle_larg:
    xor r10, r10                                                   ; Reset match flag
    call_larg help_larg, help_larg_len, _sarg_func.print_help      ; Match long help option
    call_larg ver_larg, ver_larg_len, _sarg_func.print_ver         ; Match long version option
    cmp r10, 0                                                     ; Check if any long option macro matched
    je _sarg_func.print_larg_err                                   ; Branch to error if no matches found
    ret                                                            ; Return to caller

_handle_sargs:
    push rbx                                                       ; Preserve rbx register on the stack
    mov rbx, 1                                                     ; Skip the hyphen '-' character at index 0
    jmp .handle_sarg_loop                                          ; Enter the short option parsing loop

.handle_sarg_loop:
    cmp byte [r12 + rbx], null_term                                ; Check if end of flag cluster string
    je .exit_sarg_loop                                             ; Exit loop if null terminator found
    xor r10, r10                                                   ; Reset match flag for current char validation
    push rbx                                                       ; Save current character offset index
    call_sarg hidden_sarg, _sarg_func.set_hidden                   ; Validate and match hidden flag option
    call_sarg file_sarg, _sarg_func.set_show_file                  ; Validate and match file filter option
    call_sarg dir_sarg, _sarg_func.set_show_dir                    ; Validate and match directory filter option
    call_sarg ver_sarg, _sarg_func.print_ver                       ; Validate and match version option
    pop rbx                                                        ; Restore character offset index
    cmp r10, 0                                                     ; If no macro matched this character
    je _sarg_func.print_sarg_err                                   ; Trigger error
    
.loop_iter_end:
    inc rbx                                                        ; Process next character in the flag string
    jmp .handle_sarg_loop                                          ; Repeat loop

.exit_sarg_loop:
    pop rbx                                                        ; Restore original rbx register value
    ret                                                            ; Return to caller

_sarg_func:
.set_hidden:
    mov byte [rel show_hidden], 1                                  ; Enable show_hidden flag (true)
    ret                                                            ; Return to caller

.set_show_file:
    mov byte [rel show_file], 1                                    ; Enable show_file filtering flag
    mov byte [rel show_dir], 0                                     ; Disable show_dir filtering flag
    ret                                                            ; Return to caller

.set_show_dir:
    mov byte [rel show_file], 0                                    ; Disable show_file filtering flag
    mov byte [rel show_dir], 1                                     ; Enable show_dir filtering flag
    ret                                                            ; Return to caller

.print_ver:
    syscall_print ver_msg, ver_msg_len                             ; Print version message
    jmp _start.exit_ok                                             ; Terminate program immediately

.print_help:
    syscall_print help_msg, help_msg_len                           ; Print help message
    jmp _start.exit_ok                                             ; Terminate program immediately

.print_sarg_err:
    syscall_print serr_msg, serr_msg_len                           ; Print short error prefix message
    push r11                                                       ; Preserve r11 register
    lea r11, [r12 + rbx]                                           ; Get exact address of invalid option
    syscall_println r11, 1                                         ; Print invalid character with newline
    pop r11                                                        ; Restore r11 register
    jmp _start.exit_err                                            ; Exit program with error status

.print_larg_err:
    syscall_print lerr_msg, lerr_msg_len                           ; Print long error prefix message
    syscall_println r12, r9                                        ; Print invalid argument string
    jmp _start.exit_err                                            ; Exit program with error status

_arglen_counter:
    xor r9, r9                                                     ; Initialize character counter to 0

.count_arg_len:
    cmp byte [r12 + r9], 0                                         ; Check for null terminator (0x00)
    je .end_counter                                                ; Exit loop if null terminator found
    inc r9                                                         ; Increment character count
    jmp .count_arg_len                                             ; Repeat length check loop

.end_counter:
    ret                                                            ; Return to caller

_compare_arg:
    mov rcx, 2                                                     ; Skip '--' prefix

.compare_arg_loop:
    mov al, byte [r12 + rcx]                                       ; Load byte from input argument
    mov bl, byte [rdi + rcx - 2]                                   ; Load byte from target option
    cmp al, bl                                                     ; Compare characters
    jne .arg_not_equal                                             ; Branch if characters mismatch
    cmp al, 0                                                      ; Check if end of string
    je .arg_equal                                                  ; Branch if strings match completely
    inc rcx                                                        ; Move to next character index
    jmp .compare_arg_loop                                          ; Repeat comparison loop

.arg_not_equal:
    mov rax, 0                                                     ; Return 0 (false)
    ret                                                            ; Return to caller

.arg_equal:   
    mov rax, 1                                                     ; Return 1 (true)
    ret                                                            ; Return to caller

_list_dir:
    mov rax, sys_openat                                            ; Invoke sys_openat syscall
    mov rdi, at_fdcwd                                              ; Use current working directory FD
    mov rsi, [rel fpath]                                           ; Target path parameter
    mov rdx, o_readonly                                            ; Read-only flag parameter
    mov r10, 0                                                     ; Mode parameter
    syscall                                                        ; Execute syscall

    cmp rax, 0                                                     ; Check openat return value
    jl .open_error                                                 ; Branch if syscall failed (rax < 0)
    mov [rel fd_dir], rax                                          ; Store directory file descriptor

.read_loop:
    mov rax, sys_getdents64                                        ; Invoke sys_getdents64 syscall
    mov rdi, [rel fd_dir]                                          ; Directory file descriptor parameter
    mov rsi, dir_buff                                              ; Buffer pointer parameter
    mov rdx, buff_size                                             ; Buffer size parameter (4KB)
    syscall                                                        ; Execute syscall

    cmp rax, 0                                                     ; Check getdents64 return value
    je .close_dir                                                  ; End of directory reached (rax == 0)
    jl .read_error                                                 ; Branch if syscall failed (rax < 0)
    mov rbx, rax                                                   ; Store total bytes read in rbx
    xor rcx, rcx                                                   ; Reset buffer offset index to 0

.parse_entries:
    cmp rcx, rbx                                                   ; Check if buffer fully parsed (offset >= bytes read)
    jge .read_loop                                                 ; Fetch next block of entries
    lea rdx, [dir_buff + rcx]                                      ; Calculate current entry address
    movzx r8, word [rdx + 16]                                      ; Load d_reclen (entry record length)
    lea rsi, [rdx + 19]                                            ; Load d_name (filename string address)
    cmp byte [rsi], period_dot                                     ; Check if filename starts with '.'
    jne .not_hidden                                                ; Process if it is a regular entry
    cmp byte [rel show_hidden], 1                                  ; Check if show hidden files flag is enabled
    je .not_hidden                                                 ; Process if flag is true
    jmp .skip_entry                                                ; Skip entry if hidden and flag is false

.not_hidden:
    xor r9, r9                                                     ; Initialize name length counter to 0
    cmp byte [rdx + 18], dir_type                                  ; Check if entry type corresponds to a directory
    je .dir_entry                                                  ; Branch to directory filter handler if true

.file_entry:
    cmp byte [rel show_file], 1                                    ; Check if regular file display flag is active
    je .count_name_len                                             ; Proceed to print if allowed
    jmp .skip_entry                                                ; Skip regular file entry if disallowed

.dir_entry:
    cmp byte [rel show_dir], 1                                     ; Check if directory display flag is active
    jne .skip_entry                                                ; Skip directory entry if disallowed

.count_name_len:
    cmp byte [rsi + r9], null_term                                 ; Check for null terminator in filename
    je .print_name                                                 ; Branch if end of string reached
    inc r9                                                         ; Increment name length count
    jmp .count_name_len                                            ; Repeat name length loop

.print_name:
    push rbx                                                       ; Preserve registers before syscall macro
    push rcx                                                       ; Save active buffer offset index
    push r8                                                        ; Save record length of current entry
    push r9                                                        ; Save length of filename string
    syscall_println rsi, r9                                        ; Print entry name to stdout
    pop r9                                                         ; Restore filename length value
    pop r8                                                         ; Restore record length value
    pop rcx                                                        ; Restore current buffer offset
    pop rbx                                                        ; Restore total bytes read context

.skip_entry:
    add rcx, r8                                                    ; Advance offset to next entry (rcx += d_reclen)
    jmp .parse_entries                                             ; Process next entry

.close_dir:
    mov rax, sys_close                                             ; Invoke sys_close syscall
    mov rdi, [rel fd_dir]                                          ; File descriptor parameter
    syscall                                                        ; Execute syscall
    ret                                                            ; Return to caller

.open_error:
    syscall_print oerr_msg, oerr_msg_len                           ; Print directory open error message
    jmp _start.exit_err                                            ; Exit program with error status

.read_error:
    syscall_print rerr_msg, rerr_msg_len                           ; Print directory read error message
    jmp _start.exit_err                                            ; Exit program with error status