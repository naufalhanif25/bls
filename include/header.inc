section .rodata
    ; System call constants
    sys_write equ 1                                                          ; syscall: write
    sys_read equ 0                                                           ; syscall: read
    sys_openat equ 257                                                       ; syscall: openat
    sys_getdents64 equ 217                                                   ; syscall: getdents64
    sys_close equ 3                                                          ; syscall: close
    sys_exit equ 60                                                          ; syscall: exit
    std_out equ 1                                                            ; stdout file descriptor
    std_in equ 0                                                             ; stdin file descriptor
    o_readonly equ 0                                                         ; O_RDONLY flag
    at_fdcwd equ -100                                                        ; AT_FDCWD flag

    ; Character constants
    new_ln equ 0x0A                                                          ; Newline (\n)
    null_term equ 0x00                                                       ; Null terminator (\0)
    hyphen_min equ 0x2D                                                      ; Hyphen (-)
    period_dot equ 0x2E                                                      ; Period (.)
    tab equ 0x09                                                             ; Tab (\t)
    space equ 0x20                                                           ; Space

    ; Command-line argument strings
    help_arg db hyphen_min, hyphen_min, "help", null_term                    ; --help argument
    help_arglen equ $- help_arg - 1                                          ; Length of help_arg
    ver_arg db hyphen_min, hyphen_min, "version", null_term                  ; --version argument
    ver_arglen equ $- ver_arg - 1                                            ; Length of ver_arg
    sec_arg db hyphen_min, hyphen_min, "secret", null_term                   ; --secret argument
    sec_arglen equ $- sec_arg - 1                                            ; Length of sec_arg

    buff_size equ 4096                                                       ; 4KB buffer size

    ; UI and Error messages
    help_msg db "bls", space, hyphen_min, space
        db "A simple and fast directory lister written in Assembly", new_ln  ; Help text payload
        db "Usage: bls [OPTION...] [FILE]", new_ln
        db new_ln
        db "Options:", new_ln
        db "  -h, --help", tab, tab
        db "Display this help menu and exit", new_ln
        db "  -v, --version", tab, tab
        db "Output version information and exit", new_ln
        db "  -s, --secret", tab, tab
        db "Show hidden files (files starting with .)", new_ln
    help_msglen equ $- help_msg                                              ; Length of help_msg
    ver_msg db "bls 1.0.0", new_ln                                           ; Version payload
    ver_msglen equ $- ver_msg                                                ; Length of ver_msg
    err_msg db "Command is not recognized: ", null_term                      ; Syntax error prefix
    err_msglen equ $- err_msg - 1                                            ; Length of err_msg
    oerr_msg db "Error: Failed to open directory or path", null_term         ; Open error message
    oerr_len equ $- oerr_msg                                                 ; Length of oerr_msg
    rerr_msg db "Error: Failed to read directory entries", null_term         ; Read error message
    rerr_len equ $- rerr_msg                                                 ; Length of rerr_msg

section .data
    def_fpath db ".", null_term                                              ; Default path (CWD)
    fpath dq def_fpath                                                       ; Active path pointer

    ; Program state flags
    show_sec db 0                                                            ; Show hidden files flag (false)

section .bss
    dir_buff resb buff_size                                                  ; Buffer for dirent64 structs
    fd_dir resq 1                                                            ; Directory file descriptor

%macro callmatch_larg 3
    cmp r9, %2                                                               ; Compare input and target lengths
    jne %%exit_macro                                                         ; Exit if lengths mismatch
    mov rdi, %1                                                              ; Load target string pointer
    call _compare_arg                                                        ; Compare string bytes
    cmp rax, 1                                                               ; Check if match found (rax == 1)
    je %3                                                                    ; Jump to handler if match
%%exit_macro:
    mov r8, 1                                                                ; Set fallthrough flag and exit
%endmacro

%macro callmatch_sarg 2
    xor rcx, rcx                                                             ; Clear index counter
    mov al, byte [r12 + rcx]                                                 ; Load first char of input
    cmp al, hyphen_min                                                       ; Verify it starts with a hyphen
    jne %%exit_macro                                                         ; Exit if no leading hyphen
    inc rcx                                                                  ; Advance to next character
    mov al, byte [%1 + rcx + 1]                                              ; Load short arg target character
    mov bl, byte [r12 + rcx]                                                 ; Load input flag character
    cmp al, bl                                                               ; Compare flag characters
    je %2                                                                    ; Jump to handler if match
%%exit_macro:
    mov r8, 1                                                                ; Set fallthrough flag and exit
%endmacro

%macro syscall_print 2
    mov rax, sys_write                                                       ; Specify write syscall
    mov rdi, std_out                                                         ; Target stdout
    mov rsi, %1                                                              ; Buffer address
    mov rdx, %2                                                              ; Buffer length
    syscall                                                                  ; Trigger system call
%endmacro

%macro syscall_println 2
    syscall_print %1, %2                                                     ; Print target message
    push new_ln                                                              ; Push newline char to stack
    syscall_print rsp, 1                                                     ; Print character from stack pointer
    pop r11                                                                  ; Clean up stack to r11
%endmacro

%macro syscall_exit 1
    mov rax, sys_exit                                                        ; Specify exit syscall
    mov rdi, %1                                                              ; Set exit status code
    syscall                                                                  ; Trigger system call
%endmacro