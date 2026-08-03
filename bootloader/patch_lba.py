#!/usr/bin/env python3
"""
patch_lba.py - Build a raw bootable disk image from:
  - A patched bootloader MBR (boot_*.bin)
  - A bzImage kernel
  - An initrd.cpio.xz

Patches kernel_start_lba, initrd_start_lba, and initrd_size_sectors
into the bootloader binary before writing the disk image.

Usage:
  python3 patch_lba.py --boot boot_x86_64.bin --kernel bzImage \
                        --initrd initrd.cpio.xz --output nano.img
"""

import argparse
import math
import struct
import sys
import os

SECTOR = 512
BOOT_SIG_OFF   = 510
KERNEL_LBA_OFF = 498   # offset of kernel_start_lba in boot.bin
INITRD_LBA_OFF = 502   # offset of initrd_start_lba  in boot.bin
INITRD_SEC_OFF = 506   # offset of initrd_size_sectors in boot.bin (word)


def sectors(nbytes):
    return math.ceil(nbytes / SECTOR)


def align(data, sec):
    rem = len(data) % (SECTOR * sec)
    if rem:
        data += b'\x00' * (SECTOR * sec - rem)
    return data


def main():
    ap = argparse.ArgumentParser(description='Build raw bootable disk image')
    ap.add_argument('--boot',   required=True, help='Bootloader MBR binary (512 bytes)')
    ap.add_argument('--kernel', required=True, help='bzImage file')
    ap.add_argument('--initrd', required=True, help='initrd.cpio.xz file')
    ap.add_argument('--output', required=True, help='Output raw disk image')
    args = ap.parse_args()

    # Read inputs
    with open(args.boot, 'rb') as f:
        boot = bytearray(f.read())
    with open(args.kernel, 'rb') as f:
        kernel = f.read()
    with open(args.initrd, 'rb') as f:
        initrd = f.read()

    if len(boot) != SECTOR:
        sys.exit(f'Error: bootloader must be exactly 512 bytes, got {len(boot)}')
    if boot[BOOT_SIG_OFF:BOOT_SIG_OFF+2] != b'\x55\xAA':
        sys.exit('Error: bootloader missing 0xAA55 signature')

    # Calculate LBA positions
    kernel_start_lba   = 1                                           # sector 1
    kernel_size_sectors = sectors(len(kernel))
    initrd_start_lba   = kernel_start_lba + kernel_size_sectors
    initrd_size_sectors_val = sectors(len(initrd))

    print(f"Kernel:  {len(kernel):,} bytes = {kernel_size_sectors} sectors")
    print(f"Initrd:  {len(initrd):,} bytes = {initrd_size_sectors_val} sectors")
    print(f"  kernel_start_lba  = {kernel_start_lba}")
    print(f"  initrd_start_lba  = {initrd_start_lba}")
    print(f"  initrd_size_sec   = {initrd_size_sectors_val}")

    # Patch bootloader
    struct.pack_into('<I', boot, KERNEL_LBA_OFF, kernel_start_lba)
    struct.pack_into('<I', boot, INITRD_LBA_OFF, initrd_start_lba)
    struct.pack_into('<H', boot, INITRD_SEC_OFF, initrd_size_sectors_val)

    # Pad kernel and initrd to sector boundary
    kernel_padded = kernel + b'\x00' * (kernel_size_sectors * SECTOR - len(kernel))
    initrd_padded = initrd + b'\x00' * (initrd_size_sectors_val * SECTOR - len(initrd))

    # Write disk image
    with open(args.output, 'wb') as f:
        f.write(bytes(boot))         # sector 0: bootloader MBR
        f.write(kernel_padded)       # sectors 1+: bzImage
        f.write(initrd_padded)       # after kernel: initrd

    total = SECTOR + len(kernel_padded) + len(initrd_padded)
    print(f"Output: {args.output} ({total:,} bytes = {total/1024/1024:.2f} MiB)")


if __name__ == '__main__':
    main()
