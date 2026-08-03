; stage1_x86_64.asm - Universal Stage 1 MBR Bootloader (x86_64)
; Fits within 446 bytes MBR code area.
; Detects boot media type (Floppy CHS vs HardDisk/CD EDD LBA) and loads Stage 2 (4 sectors) to 0x0000:0x0600.

[org 0x7C00]
[bits 16]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov [boot_drive], dl

    ; Move MBR out of the way (from 0x7C00 to 0x0600 is where Stage 2 goes, so relocate MBR to 0x7A00)
    mov si, 0x7C00
    mov di, 0x7A00
    mov cx, 256
    rep movsw
    jmp 0x0000:relocated

relocated:
    mov dl, [boot_drive]
    cmp dl, 0x80
    jb .read_chs

    ; Try EDD LBA extension first (INT 13h, AH=42h)
    mov si, dap
    mov ah, 0x42
    int 0x13
    jnc .ok

.read_chs:
    ; Read sectors 2-5 (Stage 2) using standard CHS (AH=02h)
    mov ax, 0x0204              ; AH=02h (read), AL=4 sectors
    mov cx, 0x0002              ; CH=0 (cylinder 0), CL=2 (sector 2)
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]
    mov bx, 0x0600              ; Destination offset
    int 0x13
    jc disk_error

.ok:
    mov dl, [boot_drive]
    jmp 0x0000:0x0600           ; Jump to Stage 2 entry point

disk_error:
    cli
    hlt

; --- Disk Address Packet for Stage 2 ---
dap:
    db 0x10, 0                  ; Packet size (16 bytes), reserved
    dw 4                        ; Sector count (4 sectors = 2 KB)
    dw 0x0600, 0x0000           ; Buffer offset:segment (0x0000:0x0600)
    dq 1                        ; Starting LBA (Sector 1)

boot_drive db 0

times 446-($-$$) db 0
times 64 db 0
dw 0xAA55
