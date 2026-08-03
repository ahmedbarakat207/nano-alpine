; stage2_i386.asm - Stage 2 loader for Nano-Alpine (i386)
; Loaded by Stage 1 to 0x0000:0x0600 from sectors 1-4.
; Uses low-memory bounce buffer at 0x1000:0000 (linear 0x10000).
; Displays centered Boot Splash screen with direct VRAM loading animation.

[org 0x0600]
[bits 16]

start:
    cld
    mov [boot_drive], dl
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; --- 1. Enable A20 Line via Fast A20 (port 0x92) ---
    in al, 0x92
    or al, 0x02
    and al, 0xFE
    out 0x92, al

    ; Draw Boot Splash Screen
    call draw_splash

    ; Query BIOS Drive Parameters (AH=08h) for floppy/disk CHS geometry
    mov ah, 0x08
    mov dl, [boot_drive]
    int 0x13
    jc .default_geom

    mov al, cl
    and al, 0x3F
    jz .default_geom
    mov [spt], al

    inc dh
    jz .default_geom
    mov [heads], dh
    jmp .geom_done

.default_geom:
    mov byte [spt], 18
    mov byte [heads], 2
.geom_done:

    ; --- 2. Load first bzImage setup sector to 0x9000:0 ---
    mov si, dap
    mov eax, [kernel_start_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    mov word [si+2], 1
    mov word [si+4], 0x0000
    mov word [si+6], 0x9000
    call do_read

    ; --- 3. Read setup_sects from kernel header ---
    push es
    mov bx, 0x9000
    mov es, bx
    mov al, [es:0x1F1]
    pop es
    test al, al
    jnz .got_setup
    mov al, 4
.got_setup:
    mov [setup_sects], al
    inc al
    mov [total_setup], al

    ; --- 4. Load remaining setup sectors to 0x9020:0 ---
    movzx cx, byte [setup_sects]
    mov si, dap
    mov [si+2], cx
    mov word [si+4], 0x0000
    mov word [si+6], 0x9020
    mov eax, [kernel_start_lba]
    inc eax
    mov [si+8], eax
    mov dword [si+12], 0
    call do_read

    ; --- 5. Compute payload sectors and start LBA ---
    push es
    mov bx, 0x9000
    mov es, bx
    movzx eax, word [es:0x1F4]   ; syssize (16-byte paragraphs)
    pop es
    shl eax, 4
    add eax, 511
    shr eax, 9                    ; sectors (ceil)
    mov [payload_sectors], eax

    movzx eax, byte [total_setup]
    add eax, [kernel_start_lba]
    mov [cur_lba], eax

    ; --- 6. Load payload to 1 MiB (0x100000) using low-memory bounce buffer ---
    mov dword [dest_linear], 0x00100000
    mov eax, [payload_sectors]
    mov [rem], eax

.loop_payload:
    mov eax, [rem]
    test eax, eax
    jz .done_payload
    cmp eax, 64
    jbe .ok_p
    mov eax, 64
.ok_p:
    mov si, dap
    mov [si+2], ax
    mov word [si+4], 0x0000
    mov word [si+6], 0x1000      ; Buffer: 0x1000:0000 (linear 0x10000)
    mov eax, [cur_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    call do_read

    ; Copy from 0x10000 to [dest_linear] via Unreal Mode
    call copy_bounce_to_dest

    movzx eax, word [dap+2]
    add [cur_lba], eax
    sub [rem], eax
    jmp .loop_payload

.done_payload:

    ; --- 7. Load initrd to 32 MiB (0x02000000) in Extended RAM ---
    mov dword [dest_linear], 0x02000000
    mov eax, [initrd_start_lba]
    mov [cur_lba], eax
    movzx eax, word [initrd_size_sectors]
    mov [rem], eax

.loop_initrd:
    mov eax, [rem]
    test eax, eax
    jz .done_initrd
    cmp eax, 64
    jbe .ok_i
    mov eax, 64
.ok_i:
    mov si, dap
    mov [si+2], ax
    mov word [si+4], 0x0000
    mov word [si+6], 0x1000
    mov eax, [cur_lba]
    mov [si+8], eax
    mov dword [si+12], 0
    call do_read

    ; Copy from 0x10000 to [dest_linear] via Unreal Mode
    call copy_bounce_to_dest

    movzx eax, word [dap+2]
    add [cur_lba], eax
    sub [rem], eax
    jmp .loop_initrd

.done_initrd:

    ; --- 8. Patch kernel boot header ---
    push es
    mov bx, 0x9000
    mov es, bx
    mov dword [es:0x218], 0x02000000    ; ramdisk_image = 32 MiB (0x02000000)
    movzx eax, word [initrd_size_sectors]
    shl eax, 9
    mov [es:0x21C], eax                 ; ramdisk_size
    mov byte [es:0x210], 0xFF           ; type_of_loader = unknown (0xFF)
    mov word [es:0x1FA], 0xFFFF         ; vid_mode = normal
    mov word [es:0x20E], 0xA33F         ; cmd_line_magic = 0xA33F

    ; Pass kernel command line: dual console (tty0 for VGA display + ttyS0 for serial)
    mov bx, 0x9800
    mov es, bx
    mov di, 0
    mov si, cmdline
.copy_cmdline:
    lodsb
    stosb
    test al, al
    jnz .copy_cmdline

    ; Point cmd_line_ptr (0x228) in header to 0x98000
    mov bx, 0x9000
    mov es, bx
    mov dword [es:0x228], 0x00098000
    pop es

    ; --- 9. Jump to kernel setup (DS=ES=SS=0x9000 as required by Linux Boot Protocol) ---
    mov ax, 0x9000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xE000
    mov dl, [boot_drive]
    jmp 0x9020:0

; --- Helper: Draw Boot Splash Screen ---
draw_splash:
    pusha
    cld
    mov ax, 0x0003              ; 80x25 text mode (clears screen)
    int 0x10

    mov ah, 0x01
    mov cx, 0x2000              ; Hide cursor
    int 0x10

    ; Row 10, Col 34: "Alpine Linux" (Bright Cyan)
    mov dh, 10
    mov dl, 34
    mov bl, 0x0B
    mov si, splash_title
    call print_str_at

    ; Row 12, Col 35: "Loading..." (Bright White)
    mov dh, 12
    mov dl, 35
    mov bl, 0x0F
    mov si, splash_sub
    call print_str_at

    ; Row 14, Col 38: "[   ]" (Light Gray)
    mov dh, 14
    mov dl, 38
    mov bl, 0x07
    mov si, splash_box
    call print_str_at
    popa
    ret

; --- Helper: Direct Video RAM Spinner Update (0xB800:2320 = Row 14, Col 40) ---
update_spinner:
    push es
    push bx
    push ax

    inc byte [spinner_tick]
    test byte [spinner_tick], 3  ; Update frame every 4 ticks
    jnz .skip

    mov ax, 0xB800
    mov es, ax

    movzx bx, byte [spinner_idx]
    mov al, [spinner_chars + bx]
    inc bl
    and bl, 3
    mov [spinner_idx], bl

    mov [es:2320], al           ; Write spinner char to VRAM
    mov byte [es:2321], 0x0E    ; Bright Yellow attribute

.skip:
    pop ax
    pop bx
    pop es
    ret

print_str_at:
    pusha
    cld
    mov ah, 0x02
    mov bh, 0
    int 0x10
.next_char:
    lodsb
    test al, al
    jz .done
    mov ah, 0x09
    mov bh, 0
    mov cx, 1
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    jmp .next_char
.done:
    popa
    ret

; --- Helper: Copy chunk from bounce buffer (0x10000) to extended RAM using Unreal Mode ---
copy_bounce_to_dest:
    push ds
    push es
    pusha
    cld

    cli
    lgdt [gdt_ptr]
    mov eax, cr0
    or al, 1
    mov cr0, eax        ; Enable PE
    jmp $+2             ; Flush pipeline

    mov ax, 0x08        ; Load 4GB descriptor into DS and ES
    mov ds, ax
    mov es, ax

    and al, 0xFE
    mov cr0, eax        ; Disable PE
    sti

    movzx ecx, word [dap+2]
    shl ecx, 9                   ; bytes = sectors * 512
    mov esi, 0x00010000          ; source linear
    mov edi, [dest_linear]       ; dest linear
    add [dest_linear], ecx       ; advance dest linear
    shr ecx, 2                   ; dwords
    a32 rep movsd                ; copy dwords using 32-bit addresses

    popa
    pop es
    pop ds
    ret

; --- Helper: Fast Universal Sector Read (EDD LBA with Fast Multi-Sector CHS Track fallback) ---
do_read:
    push ds
    push es
    pusha
    cld
    call update_spinner

    mov dl, [boot_drive]
    cmp dl, 0x80
    jb .use_chs

    xor ax, ax
    mov ds, ax
    mov si, dap
    mov ah, 0x42
    int 0x13
    jnc .read_ok

.use_chs:
    movzx ecx, word [dap+2]       ; total sectors to read
    mov eax, [dap+8]              ; starting LBA
    mov bx, [dap+4]               ; buffer offset
    mov es, [dap+6]               ; buffer segment

.chs_loop:
    test cx, cx
    jz .read_ok

    push cx                       ; save remaining total count
    push eax                      ; save current LBA
    push bx                       ; save buffer offset

    xor edx, edx
    movzx si, byte [spt]
    div si                        ; ax = LBA / spt, dx = LBA % spt

    inc dx                        ; dx = sector number (1..spt)
    mov di, dx                    ; DI = sector number (1..spt)

    movzx dx, byte [spt]
    sub dx, di
    inc dx                        ; DX = sectors left on current track
    cmp cx, dx
    jbe .take_cx
    mov cx, dx                    ; CX = min(total_rem, sectors_left_on_track)
.take_cx:
    push cx                       ; save sectors_to_read

    xor dx, dx
    movzx si, byte [heads]
    div si                        ; ax = cylinder, dx = head
    mov ch, al                    ; CH = cylinder
    mov dh, dl                    ; DH = head
    mov ax, di
    mov cl, al                    ; CL = sector number (1..spt)

    pop ax                        ; AL = sectors_to_read
    pop bx                        ; BX = buffer offset
    mov dl, [boot_drive]          ; DL = boot_drive
    mov ah, 0x02                  ; AH = 2 (Read CHS)
    int 0x13
    jnc .chs_ok

    ; Retry once with disk reset
    push ax
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13
    pop ax

    mov ah, 0x02
    mov dl, [boot_drive]
    int 0x13
    jc .read_err

.chs_ok:
    movzx ebp, ax                  ; EBP = sectors read (AL)
    shl ax, 9                     ; AX = sectors * 512
    add bx, ax                    ; advance buffer offset
    jnc .no_seg
    mov ax, es
    add ax, 0x1000
    mov es, ax
.no_seg:

    pop eax                       ; restore original LBA
    add eax, ebp                  ; LBA += sectors_read

    pop cx                        ; restore total count remaining
    sub cx, bp                    ; count -= sectors_read
    jmp .chs_loop

.read_ok:
    popa
    pop es
    pop ds
    ret

.read_err:
    cli
    hlt

cmdline db "console=ttyS0,115200 console=tty0 quiet loglevel=0", 0
splash_title db "Alpine Linux", 0
splash_sub   db "Loading...", 0
splash_box   db "[   ]", 0
spinner_chars db "|/-\\"
spinner_idx   db 0
spinner_tick  db 0

; =================== GDT Descriptor for Unreal Mode ===================
gdt_start:
    dq 0x0000000000000000       ; Null descriptor
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x92, 0xCF, 0x00 ; 4GB Data segment selector (0x08)
gdt_end:

gdt_ptr:
    dw gdt_end - gdt_start - 1  ; GDT Limit
    dd gdt_start                ; GDT Base

; =================== Shared DAP ===================
dap:
    db 0x10, 0        ; size=16, reserved
    dw 0              ; sector count (patched)
    dw 0, 0           ; buf_off, buf_seg (patched)
    dq 0              ; LBA (patched)

; =================== Variables ===================
boot_drive          db 0
setup_sects         db 0
total_setup         db 0
payload_sectors     dd 0
cur_lba             dd 0
rem                 dd 0
dest_linear         dd 0
spt                 db 18
heads               db 2

; ===== Patched by patch_lba.py =====
kernel_start_lba    dd 5      ; bzImage starts at sector 5
initrd_start_lba    dd 0      ; patched at build time
initrd_size_sectors dw 0      ; patched at build time
