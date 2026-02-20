org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
    jmp main_start

;prints a null terminatedstring
;   - ds:si will point to beginning of string
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

main_start:
    
    ;sets up data segment
    xor ax, ax
    mov ds, ax
    mov es, ax
    
    ;sets up the stack
    mov ss, ax
    mov sp, 0x7C00

    ;prints hello world
    mov si, helloword_msg
    call print_str

.halt:
    jmp .halt

helloword_msg: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h