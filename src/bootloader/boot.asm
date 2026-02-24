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
bdb_media_descriptor_type:  db 0xF0
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

;extended boot record
ebr_drive_number:   db 0
                    db 0
ebr_signature:      db 0x29
ebr_volume_id:      dw 0
ebr_volume_label:   db 'Adrian L OS'
ebr_system_id:      db 'FAT12   '

start:
    
    ;sets up data segment
    mov ax, 0
    mov ds, ax
    mov es, ax
    
    ;sets up the stack
    mov ss, ax
    mov sp, 0x7C00
    
    ;some BIOSes start at 07C0:0000 instead of 0000:7C0
    push es
    push WORD .after
    retf


.after:

    ;try to read data from disk
    mov [ebr_drive_number], dl

    mov si, msg_loading
    call print_str

    ;read drive params
    push es
    mov ah, 0x08
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                    ;removes top two bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx ;sector count

    inc dh
    mov [bdb_heads], dh             ;head count


    ;read fat root dir
    mov ax, [bdb_sectors_per_fat]   ;lba of the root directory = reserved * fats * fat size
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                          ;ax = (fats*sectors_per_fat)
    add ax, [bdb_reserved_sectors]  ;ax = lba of root dir
    push ax

    ;compute the size of the root dir = 32 * number_of_entries / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                       ; ax *= 32
    xor dx, dx                      ; dx = 0
    div word [bdb_bytes_per_sector] ; ax /= bytes per sector

    test dx, dx                     ; if dx != 0, then add 1
    jz .root_dir_after
    inc ax

.root_dir_after:

    mov cl, al                      ; cl = number of sectors to read (size of the root directory)
    pop ax                          ; ax = lba of root dir
    mov dl, [ebr_drive_number]      ; dl = drive number (saved it from previous intsructions)
    mov bx, buffer
    call disk_read

    ;search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11
    push di
    
    ;repe repeats a string instruction while the operands are equal(zf == 1) or until the cs register reaches 0
    repe cmpsb      ;compares two bytes lcoated in ds:si and es:di
    pop di
    je .found_kernel
    
    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ;kernel is not found
    jmp kernel_not_found_error

.found_kernel:
    
    ;di should have address to the entry
    mov ax, [di + 26]
    mov [kernel_cluster], ax
    
    ; load FAT from the disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read


    ;real kernel and process fat chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:

    ;read the next cluster
    mov ax, [kernel_cluster]

    ;not nice since hardcoded value
    add ax, 31                      ;first cluster is (kernel_cluster-2)*sectors_per_cluster + start_sector
                                    ; start sector = reserved + fat * root dir size = 1 + 18 + 134 = 33
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ;compute locaiton of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                          ; ax = index of entry in FAT, dx = cluster and 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF


.next_cluster_after:
    cmp ax, 0x0FF8                  ; end of the chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:

    ; jump to our kernel
    mov dl, [ebr_drive_number]      ; boost device in dl
    mov ax, KERNEL_LOAD_SEGMENT     ; set segment registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot         ; ideally never happen

    cli                             ;disable interrupts, traps the CPU
    hlt

floppy_error:
    mov si, msg_read_failed
    call print_str
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call print_str
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0    ;jmps to beginning of bios, should begin reboot

.halt:
    cli         ;disable interrupts so CPU can't get out of halt state
    hlt

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

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x02
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
;-------------------------------------------------------

;resets disk controller ---------------------------------
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
;--------------------------------------------------------


;prints string-------------------------------------------
print_str:
    push si
    push ax
    push bx

.loop:
    lodsb           ;loads next char into al
    or al, al       ;verifies if next character is null
    jz .done

    mov ah, 0x0E    ;calls bios interrupt
    mov bh, 0
    int 0x10
    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret
;---------------------------------------------------------


msg_loading:             db 'Loading...', ENDL, 0
msg_read_failed:         db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:    db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:         db 'KERNEL  BIN'
kernel_cluster:          dw 0


KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer: