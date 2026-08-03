# Bootloader

Custom 512-byte MBR bootloaders for Nano-Alpine Linux. Replaces ISOLINUX for
raw disk image booting (`nano.img`) instead of ISO format.

## Files

| File | Description |
|------|-------------|
| `boot_x86_64.asm` | 64-bit bootloader — loads `bzImage` (x86_64) + initrd to 1 MiB / 2 MiB |
| `boot_i386.asm` | 32-bit bootloader — loads `bzImage` (i386) + initrd to 1 MiB / 4 MiB |
| `patch_lba.py` | Python tool that patches LBA offsets and builds the final raw disk image |
| `Makefile` | Builds `.bin` binaries and optionally raw disk images |

## Architecture Differences

| Feature | `boot_x86_64.asm` | `boot_i386.asm` |
|---------|-------------------|-----------------|
| Kernel target | 64-bit (long mode) | 32-bit (protected mode) |
| Initrd load address | **2 MiB** (0x200000) | **4 MiB** (0x400000) |
| Initrd DAP | EDD 2.0 (24-byte, 64-bit addr) | Standard DAP (16-byte, seg:off) |
| Kernel entry | `0x9020:0000` | `0x9020:0000` |

## Build

```bash
# Install NASM
sudo apt-get install nasm

# Build both bootloader binaries
make -C bootloader

# Build x86_64 raw disk image (requires ../bzImage and ../initrd.cpio.xz)
make -C bootloader disk_x86_64

# Build i386 raw disk image (requires ../bzImage_i386 and ../initrd.cpio.xz)
make -C bootloader disk_i386
```

## Disk Layout

```
Sector 0 (512B):  Bootloader MBR (boot_*.bin with patched LBA fields)
Sector 1+:        bzImage (kernel)
After kernel:     initrd.cpio.xz
```

## Patching Manually

Use `patch_lba.py` to build the full image automatically:

```bash
python3 bootloader/patch_lba.py \
  --boot  bootloader/boot_x86_64.bin \
  --kernel bzImage \
  --initrd initrd.cpio.xz \
  --output nano.img
```

Then boot with QEMU:

```bash
qemu-system-x86_64 -drive format=raw,file=nano.img -m 128M
qemu-system-i386   -drive format=raw,file=nano_i386.img -m 128M
```
