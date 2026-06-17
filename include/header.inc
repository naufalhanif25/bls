section .rodata
    ; System call constants
    sys_write equ 1                                                                     ; syscall: write
    sys_read equ 0                                                                      ; syscall: read
    sys_openat equ 257                                                                  ; syscall: openat
    sys_getdents64 equ 217                                                              ; syscall: getdents64
    sys_close equ 3                                                                     ; syscall: close
    sys_exit equ 60                                                                     ; syscall: exit
    std_out equ 1                                                                       ; stdout file descriptor
    std_in equ 0                                                                        ; stdin file descriptor
    o_readonly equ 0                                                                    ; O_RDONLY flag
    at_fdcwd equ -100                                                                   ; AT_FDCWD flag
    file_type equ 0x08                                                                  ; DT_REG file type constant
    dir_type equ 0x04                                                                   ; DT_DIR directory type constant

    ; Character constants
    new_ln equ 0x0A                                                                     ; Newline (\n)
    null_term equ 0x00                                                                  ; Null terminator (\0)
    hyphen_min equ 0x2D                                                                 ; Hyphen (-)
    period_dot equ 0x2E                                                                 ; Period (.)
    tab equ 0x09                                                                        ; Tab (\t)
    space equ 0x20                                                                      ; Space

    ; Short arguments
    hidden_sarg db 'h'                                                                  ; Short flag for hidden files
    file_sarg db 'f'                                                                    ; Short flag for files only
    dir_sarg db 'd'                                                                     ; Short flag for directories only
    ver_sarg db 'v'                                                                     ; Short flag for version

    ; Long arguments
    help_larg db "help", null_term                                                      ; --help argument
    help_larg_len equ $- help_larg - 1                                                  ; Length of help_arg
    ver_larg db "version", null_term                                                    ; --version argument
    ver_larg_len equ $- ver_larg - 1                                                    ; Length of ver_arg

    buff_size equ 4096                                                                  ; 4KB buffer size

    ; UI and Error messages
    help_msg db "bls - A simple and fast directory lister written in Assembly", new_ln  ; Help text payload
        db "Usage: bls [OPTION...] [FILE]", new_ln
        db new_ln
        db "Options:", new_ln
        db "  -d", tab, tab, "Display directories only", new_ln
        db "  -f", tab, tab, "Display files only", new_ln
        db "  -h", tab, tab, "Show hidden files (files starting with .)", new_ln
        db "      --help", tab, "Display this help menu and exit", new_ln
        db "  -v, --version", tab, "Output version information and exit", new_ln
        db new_ln
        db "Report bugs to: https://github.com/username/bls/issues", new_ln
    help_msg_len equ $- help_msg                                                        ; Length of help_msg
    ver_msg db "bls 1.0.0", new_ln                                                      ; Version payload
    ver_msg_len equ $- ver_msg                                                          ; Length of ver_msg
    serr_msg db "Invalid option: -", null_term                                          ; Short option error prefix
    serr_msg_len equ $- serr_msg - 1                                                    ; Length of serr_msg
    lerr_msg db "Unrecognized option: ", null_term                                      ; Long option error prefix
    lerr_msg_len equ $- lerr_msg - 1                                                    ; Length of lerr_msg
    oerr_msg db "Error: Failed to open directory or path", new_ln                       ; Open error message
    oerr_msg_len equ $- oerr_msg                                                        ; Length of oerr_msg
    rerr_msg db "Error: Failed to read directory entries", new_ln                       ; Read error message
    rerr_msg_len equ $- rerr_msg                                                        ; Length of rerr_msg

section .data
    def_fpath db ".", null_term                                                         ; Default path (CWD)
    fpath dq def_fpath                                                                  ; Active path pointer

    ; Program state flags
    show_hidden db 0                                                                    ; Show hidden files flag (false)
    show_file db 1                                                                      ; Show regular files flag (true)
    show_dir db 1                                                                       ; Show directories flag (true)

section .bss
    dir_buff resb buff_size                                                             ; Buffer for dirent64 structs
    fd_dir resq 1                                                                       ; Directory file descriptor

%macro call_larg 3
    push r9                                                                             ; Preserve r9 register
    sub r9, 2                                                                           ; Exclude '--' prefix length
    cmp r9, %2                                                                          ; Compare input and target lengths
    pop r9                                                                              ; Restore r9 register
    jne %%exit_macro                                                                    ; Exit if lengths mismatch
    mov rdi, %1                                                                         ; Load target string pointer
    call _compare_arg                                                                   ; Compare string bytes
    cmp rax, 1                                                                          ; Check if match found (rax == 1)
    jne %%exit_macro                                                                    ; Exit if string mismatch
%%match:
    mov r10, 1                                                                          ; Set flag match found
    je %3                                                                               ; Jump to the target handler
%%exit_macro:
    mov r8, 1                                                                           ; Set fallback execution flag
%endmacro

%macro call_sarg 2
    push rcx                                                                            ; Preserve rcx register on the stack
    mov rcx, [rsp + 8]                                                                  ; Load the previously pushed rbx value from stack
    mov al, byte [rel %1]                                                               ; Load short arg target character
    mov bl, byte [r12 + rcx]                                                            ; Load input flag character
    pop rcx                                                                             ; Restore original rcx register value
    cmp al, bl                                                                          ; Compare flag characters
    jne %%exit_macro                                                                    ; Exit if character mismatch
%%match:
    mov r10, 1                                                                          ; Set flag match found
    call %2                                                                             ; Execute matching argument subroutine
%%exit_macro:
    mov r8, 1                                                                           ; Set fallback execution flag
%endmacro

%macro syscall_print 2
    mov rax, sys_write                                                                  ; Specify write syscall
    mov rdi, std_out                                                                    ; Target stdout
    mov rsi, %1                                                                         ; Buffer address
    mov rdx, %2                                                                         ; Buffer length
    syscall                                                                             ; Trigger system call
%endmacro

%macro syscall_println 2
    syscall_print %1, %2                                                                ; Print target message
    push r11                                                                            ; Preserve r11
    mov r11, new_ln                                                                     ; Load newline character value
    push r11                                                                            ; Push newline char to stack
    syscall_print rsp, 1                                                                ; Print character from stack pointer
    pop r11                                                                             ; Clean up stack
    pop r11                                                                             ; Restore r11
%endmacro

%macro syscall_exit 1
    mov rax, sys_exit                                                                   ; Specify exit syscall
    mov rdi, %1                                                                         ; Set exit status code
    syscall                                                                             ; Trigger system call
%endmacro