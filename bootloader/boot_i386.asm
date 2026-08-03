; boot_i386.asm - 512-byte bootloader for Nano-Alpine Linux (i386 / 32-bit)
; Loads bzImage (i386) + initrd.cpio.xz from raw disk sectors.
;
; Layout on disk (raw image):
;   Sector 0:         This bootloader (boot.bin)
;   Sector 1+:        bzImage (i386 kernel)
;   After bzImage:    initrd.cpio.xz
;
; The kernel setup header transitions to 32-bit protected mode automatically.
; Patch kernel_start_lba, initrd_start_lba, initrd_size_sectors before writing to disk.
;
; Assemble with: nasm -f bin -o boot_i386.bin boot_i386.asm

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

    ; --- 1. Load the first setup sector to 0x9000:0000 ---
    mov si, dap_setup_first
    mov eax, [kernel_start_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    mov ah, 0x42
    int 0x13
    jc disk_error

    ; --- 2. Read setup_sects and compute total setup size ---
    mov bx, 0x9000
    mov es, bx
    mov al, [es:0x1F1]          ; setup_sects from boot header
    test al, al
    jnz .got_setup
    mov al, 4
.got_setup:
    mov [setup_sects], al        ; N extra sectors
    inc al
    mov [total_setup], al        ; N+1 total

    ; --- 3. Load remaining setup sectors to 0x9020:0000 ---
    mov si, dap_setup_rest
    movzx cx, byte [setup_sects]
    mov [si+2], cx               ; sector count
    mov word [si+4], 0
    mov word [si+6], 0x9020
    mov eax, [kernel_start_lba]
    inc eax
    mov [si+8], eax
    mov dword [si+12], 0
    mov ah, 0x42
    int 0x13
    jc disk_error

    ; --- 4. Compute payload (protected mode) size in sectors ---
    ; For i386: syssize contains the 32-bit protected-mode kernel size
    movzx eax, word [es:0x1F4]   ; syssize (16-byte paragraphs)
    shl eax, 4                   ; convert to bytes
    add eax, 511
    shr eax, 9                   ; convert to sectors (ceil)
    mov [payload_sectors], ax
    ; payload LBA = kernel_start + total_setup
    movzx eax, byte [total_setup]
    add eax, [kernel_start_lba]
    mov [payload_lba], eax

    ; --- 5. Load 32-bit kernel payload to 1 MiB (0x100000) ---
    ; Using real-mode trick: seg:off 0xFFFF:0x0010 -> linear 0x100000
    mov si, dap_payload
    mov ax, [payload_sectors]
    mov [si+2], ax
    mov word [si+4], 0x0010
    mov word [si+6], 0xFFFF
    mov eax, [payload_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    mov ah, 0x42
    int 0x13
    jc disk_error

    ; --- 6. Load initrd to 4 MiB (0x400000) ---
    ; i386 uses 32-bit physical addresses; stay well below 4 GiB limit.
    ; Using seg:off: 0x4000:0x0000 -> linear 0x400000
    mov si, dap_initrd
    mov ax, [initrd_size_sectors]
    mov [si+2], ax
    mov word [si+4], 0x0000
    mov word [si+6], 0x4000      ; 0x4000:0x0000 = 0x40000 (4 MiB)
    mov eax, [initrd_start_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    mov ah, 0x42
    int 0x13
    jc disk_error

    ; --- 7. Patch kernel setup header (boot protocol fields) ---
    mov bx, 0x9000
    mov es, bx
    mov dword [es:0x218], 0x00400000    ; ramdisk_image = 4 MiB (linear)
    movzx eax, word [initrd_size_sectors]
    shl eax, 9                          ; sectors -> bytes
    mov [es:0x21C], eax                 ; ramdisk_size
    mov byte [es:0x210], 0xFF           ; type_of_loader = unknown (0xFF)
    ; vid_mode = normal (0xFFFF = current BIOS mode)
    mov word [es:0x1FA], 0xFFFF

    ; --- 8. Jump to kernel setup entry point at 0x9020:0000 ---
    ; Kernel setup takes over and enters 32-bit protected mode (i386)
    mov dl, [boot_drive]
    jmp 0x9020:0

disk_error:
    mov si, err_msg
.loop:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp .loop
.halt:
    cli
    hlt
    jmp .halt

err_msg db "Disk error!", 0

; =================== Disk Address Packet templates ===================

dap_setup_first:
    db 0x10                ; packet size = 16 bytes
    db 0                   ; reserved
    dw 1                   ; load 1 sector
    dw 0, 0x9000           ; buffer: 0x9000:0000
    dq 0                   ; LBA (patched at runtime)

dap_setup_rest:
    db 0x10
    db 0
    dw 0                   ; sector count (patched)
    dw 0, 0x9020           ; buffer: 0x9020:0000
    dq 0                   ; LBA (patched)

dap_payload:
    db 0x10
    db 0
    dw 0                   ; sector count (patched)
    dw 0x0010, 0xFFFF      ; seg:off -> linear 0x100000 (1 MiB)
    dq 0                   ; LBA (patched)

dap_initrd:               ; Standard DAP (16 bytes, seg:off addressing for i386)
    db 0x10                ; packet size = 16
    db 0                   ; reserved
    dw 0                   ; sector count (patched)
    dw 0x0000, 0x4000      ; seg:off -> linear 0x400000 (4 MiB) for i386
    dq 0                   ; LBA (patched)

; =================== Runtime Variables ===================

boot_drive          db 0
setup_sects         db 0
total_setup         db 0
payload_sectors     dw 0
payload_lba         dd 0

; ===== Patch these values before writing the bootloader to disk =====
kernel_start_lba    dd 1      ; LBA sector where bzImage starts (default: 1)
initrd_start_lba    dd 0      ; LBA sector where initrd.cpio.xz starts
initrd_size_sectors dw 0      ; initrd size in 512-byte sectors (e.g. 1160 for 580KB)

; Pad to 510 and write MBR signature
times 510 - ($ - $$) db 0
dw 0xAA55
