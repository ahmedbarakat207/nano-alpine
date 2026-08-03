#!/usr/bin/env python3
"""
make_iso.py - Build bootable ISO for Nano-Alpine Linux using custom MBR/El Torito bootloader.
Eliminates all dependencies on syslinux / isolinux.
"""
import os
import sys
import pycdlib

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

arch = os.environ.get("TARGET_ARCH", "x86_64")
if os.environ.get("KERNEL_BIN") == "bzImage_i386":
    arch = "i386"

img_name = f"nano_{arch}.img"
img_path = os.path.join(ROOT_DIR, img_name)
output_iso_path = os.path.join(ROOT_DIR, f"linux_{arch}.iso" if arch == "i386" else "linux.iso")

if not os.path.exists(img_path):
    sys.exit(f"Error: Raw disk image missing at {img_path}. Please run build.sh / patch_lba.py first.")

img_size = os.path.getsize(img_path)
sectors = img_size // 512

iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=True, rock_ridge='1.12')

# Add raw disk image to ISO as El Torito floppy boot file (1.44MB or 2.88MB floppy emulation)
iso.add_file(img_path, '/NANO.IMG;1', rr_name='nano.img')
if sectors in (2400, 2880, 5760):
    iso.add_eltorito('/NANO.IMG;1', bootcatfile='/BOOT.CAT;1', media_name='floppy', boot_load_size=sectors)
else:
    iso.add_eltorito('/NANO.IMG;1', bootcatfile='/BOOT.CAT;1', media_name='noemul', boot_load_size=4)

iso.write(output_iso_path)
iso.close()

print(f"ISO successfully created using custom bootloader: {output_iso_path}")
