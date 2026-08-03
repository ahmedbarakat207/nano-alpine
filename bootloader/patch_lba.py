#!/usr/bin/env python3
"""
patch_lba.py - Build a raw bootable disk image for Nano-Alpine Linux.

Disk layout (2-stage bootloader):
  Sector 0    (512B): Stage 1 MBR  (stage1_*.bin)
  Sectors 1-4 (2KB):  Stage 2 loader (stage2_*.bin, padded to 4 sectors)
  Sector 5+:          bzImage kernel
  After kernel:       initrd.cpio.xz

patch_lba.py patches initrd_start_lba and initrd_size_sectors into Stage 2.
kernel_start_lba is dynamically located.

Usage:
  python3 patch_lba.py --arch x86_64
  python3 patch_lba.py --arch i386
"""

import argparse
import math
import os
import struct
import sys

SECTOR   = 512
STAGE2_SECTORS = 4          # Stage 2 occupies sectors 1-4
KERNEL_START_LBA = 5        # Fixed: kernel always at sector 5

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.dirname(SCRIPT_DIR)


def sectors(nbytes):
    return math.ceil(nbytes / SECTOR)


def pad_to(data, n_sectors):
    target = n_sectors * SECTOR
    if len(data) > target:
        sys.exit(f'Error: data ({len(data)} bytes) exceeds {n_sectors} sectors ({target} bytes)')
    return data + b'\x00' * (target - len(data))


def main():
    ap = argparse.ArgumentParser(description='Build raw bootable Nano-Alpine disk image')
    ap.add_argument('--arch',   default='x86_64', choices=['x86_64', 'i386'])
    ap.add_argument('--stage1', help='Stage1 MBR binary (default: stage1_<arch>.bin)')
    ap.add_argument('--stage2', help='Stage2 loader binary (default: stage2_<arch>.bin)')
    ap.add_argument('--kernel', help='bzImage file (default: ../bzImage or ../bzImage_i386)')
    ap.add_argument('--initrd', help='initrd.cpio.xz file (default: ../initrd.cpio.xz)')
    ap.add_argument('--output', help='Output disk image (default: ../nano_<arch>.img)')
    args = ap.parse_args()

    arch = args.arch
    s1_path = args.stage1 or os.path.join(SCRIPT_DIR, f'stage1_{arch}.bin')
    s2_path = args.stage2 or os.path.join(SCRIPT_DIR, f'stage2_{arch}.bin')

    if arch == 'i386':
        default_kernel = os.path.join(ROOT_DIR, 'bzImage_i386')
    else:
        default_kernel = os.path.join(ROOT_DIR, 'bzImage')

    kernel_path = args.kernel or default_kernel
    initrd_path = args.initrd or os.path.join(ROOT_DIR, 'initrd.cpio.xz')
    output_path = args.output or os.path.join(ROOT_DIR, f'nano_{arch}.img')

    # Read all inputs
    for path in (s1_path, s2_path, kernel_path, initrd_path):
        if not os.path.exists(path):
            sys.exit(f'Error: not found: {path}')

    with open(s1_path, 'rb') as f: stage1 = bytearray(f.read())
    with open(s2_path, 'rb') as f: stage2 = bytearray(f.read())
    with open(kernel_path, 'rb') as f: kernel = f.read()
    with open(initrd_path, 'rb') as f: initrd = f.read()

    # Validate Stage 1
    if len(stage1) != SECTOR:
        sys.exit(f'Error: stage1 must be exactly 512 bytes, got {len(stage1)}')
    if stage1[510:512] != b'\x55\xAA':
        sys.exit('Error: stage1 missing 0xAA55 boot signature')

    # Stage 2 must fit in STAGE2_SECTORS sectors
    s2_max = STAGE2_SECTORS * SECTOR
    if len(stage2) > s2_max:
        sys.exit(f'Error: stage2 is {len(stage2)} bytes, exceeds {s2_max} bytes ({STAGE2_SECTORS} sectors)')

    # Dynamically find offset of variables (kernel_start_lba pattern: 5, 0, 0)
    magic = b'\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    klba_offset = stage2.find(magic)
    if klba_offset == -1:
        # Fallback: search for 5 at end of binary
        klba_offset = stage2.rfind(b'\x05\x00\x00\x00')
        if klba_offset == -1:
            sys.exit('Error: Could not locate kernel_start_lba magic pattern in stage2 binary')

    initrd_lba_offset = klba_offset + 4
    initrd_sec_offset = klba_offset + 8

    kernel_sec  = sectors(len(kernel))
    initrd_sec  = sectors(len(initrd))
    initrd_lba  = KERNEL_START_LBA + kernel_sec

    print(f"[{arch}] Kernel:  {len(kernel):>10,} bytes = {kernel_sec} sectors  (LBA {KERNEL_START_LBA})")
    print(f"[{arch}] Initrd:  {len(initrd):>10,} bytes = {initrd_sec} sectors  (LBA {initrd_lba})")

    # Patch Stage2
    struct.pack_into('<I', stage2, initrd_lba_offset, initrd_lba)
    struct.pack_into('<H', stage2, initrd_sec_offset, initrd_sec)

    print(f"[{arch}] Dynamically patched stage2 offsets: initrd_lba@{initrd_lba_offset:#x} initrd_sec@{initrd_sec_offset:#x}")

    total = SECTOR + len(pad_to(bytes(stage2), STAGE2_SECTORS)) + len(kernel) + len(initrd)
    kernel_padded = kernel + b'\x00' * (kernel_sec * SECTOR - len(kernel))
    initrd_padded = initrd + b'\x00' * (initrd_sec * SECTOR - len(initrd))
    stage2_padded = pad_to(bytes(stage2), STAGE2_SECTORS)

    if total <= 2880 * SECTOR:
        target_size = 2880 * SECTOR     # Standard 1.44 MB Floppy (2880 sectors)
    else:
        target_size = total             # Exact size for images larger than 1.44MB

    pad_floppy = target_size - total

    with open(output_path, 'wb') as f:
        f.write(bytes(stage1))   # Sector 0: MBR
        f.write(stage2_padded)   # Sectors 1-4: Stage 2
        f.write(kernel_padded)   # Sector 5+: bzImage
        f.write(initrd_padded)   # After kernel: initrd
        if pad_floppy > 0:
            f.write(b'\x00' * pad_floppy)

    final_size = total + pad_floppy
    print(f"[{arch}] Output: {output_path}  ({final_size:,} bytes = {final_size/1024/1024:.2f} MiB)")


if __name__ == '__main__':
    main()
