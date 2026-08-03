# Nano-Alpine Two-Stage MBR Bootloader

Custom two-stage MBR bootloaders for Nano-Alpine Linux. Replaces ISOLINUX for raw disk image booting (`nano_x86_64.img` / `nano_i386.img`).

## Files

| File | Description |
|------|-------------|
| `stage1_x86_64.asm` | 512-byte MBR Stage 1 (x86_64) — loads Stage 2 via CHS |
| `stage2_x86_64.asm` | Stage 2 Loader (x86_64) — A20, Unreal Mode, loads kernel & initrd to 1MB/32MB |
| `stage1_i386.asm` | 512-byte MBR Stage 1 (i386) — loads Stage 2 via CHS |
| `stage2_i386.asm` | Stage 2 Loader (i386) — A20, Unreal Mode, loads kernel & initrd to 1MB/32MB |
| `patch_lba.py` | Python tool that calculates LBA offsets and builds the raw disk image |
| `Makefile` | Assembles stage1 and stage2 binaries |

## Memory Mapping

| Component | Target Address | Notes |
|-----------|----------------|-------|
| Stage 1 | `0x7C00` | MBR (Sector 0) |
| Stage 2 | `0x0600` | Sectors 1–4 |
| Bounce Buffer | `0x10000` | Conventional RAM (64 KB) for 32 KB chunk transfers |
| Kernel Setup | `0x90000` | Real-mode kernel header and setup code |
| Kernel Command Line | `0x98000` | `console=ttyS0 quiet` |
| Kernel Payload | `0x100000` (1 MiB) | Extended RAM |
| InitRD Payload | `0x02000000` (32 MiB) | Extended RAM |

## Build

```bash
# Build bootloader binaries
make -C bootloader

# Build x86_64 raw disk image
make -C bootloader disk_x86_64

# Build i386 raw disk image
make -C bootloader disk_i386
```

## Running

```bash
# Boot using run.sh script:
./run.sh x86_64 -n
./run.sh i386 -n
```
