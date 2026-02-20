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

    ;prints hello world
    mov si, helloword_msg
    call print_str

.halt:
    jmp .halt

helloword_msg: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h