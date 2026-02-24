org 0x0
bits 16

%define ENDL 0x0D, 0x0A

main_start:
    
    mov si, msg_from_kernel
    call print_str

    cli
    hlt

;----prints null terminated string-------
print_str:
    push si
    push ax

.loop:
    lodsb           ;loads next char into al
    or al, al       ;verifies if next character is null
    jz .done

    mov ah, 0x0e    ;calls bios interrupt
    int 0x10
    jmp .loop

.done:
    pop ax
    pop si
    ret
;--------------------------------------


msg_from_kernel: db 'Booted into the kernel', ENDL, 0