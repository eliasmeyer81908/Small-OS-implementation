org 0x0
bits 16

%define ENDL 0x0D, 0x0A

start:
    cli

    mov ax, cs
    mov ds, ax
    mov es, ax

    mov si, msg_from_kernel
    call print_str

    mov si, msg_enablingA20
    call print_str

    ;enable the A20 Line
    in al, 0x92
    test al, 2
    jnz .enabled
    or al, 2
    and al, 0xFE
    out 0x92, al

.enabled:

    mov si, msg_setting_up_gdt
    call print_str
    
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE_SEG:protected_mode

bits 32
protected_mode:

    ;set up the segment registers
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000

    mov esi, msg_done_with_gdt
    call print

    jmp $

    cli
    hlt

;----prints null terminated string (only for real mode) -------
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

;------------------prints null terminated string for protected mode
print:
    push esi
    push edi

    mov edi, 0xB8000

    .loop:
        lodsb
        test al, al
        jz .done

        mov [edi], al
        mov byte [edi+1], 0x07

        add edi, 2
    jmp .loop

    .done:
        cld
        pop edi
        pop esi
        ret
;--------------------------------------------


;gdt setup
gdt_begin:                  DQ 0            ;null descriptor (8 bytes long)
gdt_kernel_code_segment:    DW 0xFFFF, 0    ;kernel code segment (4GB)
                            DB 0            ;segment descriptor

                            ;(big endian first so small bit starting from left)
                            ;first bit is access flag, which is set by first access by CPU
                            ;second bit is set when the segment is readable
                            ;third bit allows code segments to jump to this segment if set
                            ;fourth bit specifies if code segment or data segment (set since code segment)
                            ;so: 1010

                            ;bit 12 - set if the segment is either a a data or code segment
                            ;bit 13&14 bits determine the privilege level, 0 most, 3 least
                            ;bit 15 is the present flag, which should be set
                            ;so: 1001
                            DB 10011010b    

                            ; bits 0-3 is the last bits in segment limit, so set to 0Fh
                            ; bit 4 represents a flag of 'Available to System Programmers' and is ignored by the CPU
                            ; meaning that you can use this bit for your own choice
                            ;bit 5 is reserved by intel and should be set to 0
                            ;bit 7 if set, makes the limiter multiply segment limit by 4kB, set it
                            ;so: 11001111
                            DB 11001111b
                            DB 0            ;base address which is 0

; keep the segments with defaulted values as the first segment to mimic flat data
; each segment is 4Mb

gdt_kernel_data_segment:    DW 0xFFFF, 0
                            DB 0
                            DB 10010010b
                            DB 11001111b
                            DB 0

user_mode_code_segment:     DW 0xFFFF, 0
                            DB 0
                            DB 10011010b
                            DB 11001111b
                            DB 0

user_mode_data_segment:     DW 0xFFFF, 0
                            DB 0
                            DB 10010010b
                            DB 11001111b
                            DB 0

tss_segment:                DW 0xFFFF, 0
                            DB 0
                            DB 10011010b
                            DB 11001111b
                            DB 0

gdt_end:
gdt_descriptor:
    dw gdt_end - gdt_begin - 1
    dd gdt_begin

CODE_SEG equ gdt_kernel_code_segment - gdt_begin
DATA_SEG equ gdt_kernel_data_segment - gdt_begin

msg_from_kernel:        db 'Booted into the kernel', ENDL, 0
msg_enablingA20:        db 'Enabling A20 Line', ENDL, 0
msg_setting_up_gdt:     db 'Loading the gdt table', ENDL, 0
msg_done_with_gdt:      db 'Done setting up the glob desc table', 0

times 510-($-$$) db 0
dw 0xAA55