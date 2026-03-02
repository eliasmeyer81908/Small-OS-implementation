org 0x0
bits 16

%define ENDL 0x0D, 0x0A

gdt_begin:                  DQ 0            ;null descriptor (8 bytes long)
gdt_kernel_code_segment:    DW 0x0FFFFF, 0  ;kernel code segment (4GB)
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

                            DB 0, 0         ;two bytes since going frmo x0008 to x0010

gdt_kernel_data_segment:    DW 0x0FFFFF, 0
                            DB 0
                            DB 10011010b
                            DB 11001111b
                            DB 0

user_mode_code_segment:     DW 0x0FFFFF, 0
                            DB 0
                            DB 10011010b
                            DB 11001111b
                            DB 0

user_mode_data_segment:     DW 0x0FFFF, 0
                            DB 0
                            DB 10011010b
                            DB 11001111b
                            DB 0

;TSS - set up later


gdt_end:
    db gdt_end - gdt_begin
    dw gdt_begin


main_start:
    
    mov si, msg_from_kernel
    call print_str

    mov si, msg_setting_up_gdt
    call print_str
    
    ;reset data segment and load gdt
    cli
    xor ax, ax
    mov dx, ax
    lgdt [gdt_end]
    sti

    ;switch to protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax


cleared_pipe:
    mov si, msg_done_with_gdt
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


msg_from_kernel:        db 'Booted into the kernel', ENDL, 0
msg_setting_up_gdt:     db 'Setting up the glob desc table', ENDL, 0
msg_done_with_gdt:      db 'Done setting up the glob desc table', ENDL, 0