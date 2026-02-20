org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;FAT12 header
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0x0E0
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0x0F0
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

;extended boot record
ebr_drive_number:   db 0
                    db 0
ebr_signature:      db 0x29
ebr_volume_id:      db 0x12, 0x34, 0x56, 0x78
ebr_volume_label:   db 'Adrian L OS'
ebr_system_id:      db 'FAT12   '


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

    ;try to read data from disk
    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    ;prints hello world
    mov si, helloword_msg
    call print_str

    cli             ;disable interrupts
    hlt

floppy_error:
    mov si, msg_read_failed
    call print_str
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0    ;jmps to beginning of bios, should begin reboot

.halt:
    cli         ;disable interrupts so CPU can't get out of halt state
    jmp .halt

;converts lba to chs
;takes lba in ax
;return chs address in following format:
; cx - [bits 0-5]: sector number
; cx - [bits 6-15]: cylinder number
; dx - dh: head number
lba_to_chs:

    push ax
    push dx

    xor dx, dx

    ;makes ax = LBA / sectorsPerTrack
    ;makes dx = LBA % sectorsPerTrack
    div WORD [bdb_sectors_per_track]

    inc dx                       ;dx = (LBA % sectorsPerTrack + 1) = sector number
    mov cx, dx

    xor dx, dx

    ;makes ax = (LBA / sectorsPerTrack) / Heads
    ;makes dx = (LBA / sectorsPerTrack) % Heads
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret


;reads sectors from a disk
; params:
;   - ax: LBA address
;   - cl: number of sectors to read (only up to 128 bytes)
;   - dl: drive number
;   - es:bx: memory address where to store read date
disk_read:

    ;save registers
    push ax
    push bx
    push cx
    push dx
    push di

    push cs
    call lba_to_chs
    pop ax

    mov ax, 02h
    mov di, 3       ;retry counter

.retry:
    pusha   ;save all registers
    stc     ;sets carry flag
    int 13h
    jnc .done
    popa
    
    ;failed read
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    jmp floppy_error
    

.done:
    popa

    ;restore registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;resets disk controller
; params:
;   dl: drive number
disk_reset:
    pusha
    xor ah, ah
    stc
    int 13h
    jc floppy_error
    popa
    ret


helloword_msg:      db 'Hello World!', ENDL, 0
msg_read_failed:    db 'Failed to read from disk', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h