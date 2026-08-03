#!/usr/bin/env python3
import io
import os
import sys
import pycdlib

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_file(candidates, name):
    for path in candidates:
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"Could not find required bootloader file '{name}'. Checked: {candidates}")

isolinux_candidates = [
    os.path.join(ROOT_DIR, ".syslinux", "isolinux.bin"),
    "/tmp/syslinux-6.03/bios/core/isolinux.bin",
    "/usr/lib/ISOLINUX/isolinux.bin",
    "/usr/lib/syslinux/isolinux.bin",
    "/usr/lib/syslinux/bios/isolinux.bin",
    "/usr/share/syslinux/isolinux.bin",
]

ldlinux_candidates = [
    os.path.join(ROOT_DIR, ".syslinux", "ldlinux.c32"),
    "/tmp/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32",
    "/usr/lib/syslinux/modules/bios/ldlinux.c32",
    "/usr/lib/syslinux/ldlinux.c32",
    "/usr/lib/syslinux/bios/ldlinux.c32",
    "/usr/share/syslinux/ldlinux.c32",
]

isolinux_bin = find_file(isolinux_candidates, "isolinux.bin")
ldlinux_c32 = find_file(ldlinux_candidates, "ldlinux.c32")

kernel_bin_name = os.environ.get("KERNEL_BIN", "bzImage")
if not os.path.exists(os.path.join(ROOT_DIR, kernel_bin_name)) and os.path.exists(os.path.join(ROOT_DIR, "bzImage_i386")):
    kernel_bin_name = "bzImage_i386"

bzimage_path = os.path.join(ROOT_DIR, kernel_bin_name)
initrd_path = os.path.join(ROOT_DIR, "initrd.cpio.xz")
output_iso_path = os.path.join(ROOT_DIR, "linux.iso")

if not os.path.exists(bzimage_path):
    sys.exit(f"Error: Kernel binary missing at {bzimage_path}. Please run build.sh first.")

if not os.path.exists(initrd_path):
    sys.exit(f"Error: Initrd missing at {initrd_path}. Please run build.sh first.")

iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=True, rock_ridge='1.12')

# Create ISOLINUX directory
iso.add_directory('/ISOLINUX', rr_name='isolinux')

# Add bootloader files in isolinux directory
iso.add_file(isolinux_bin, '/ISOLINUX/ISOLINUX.BIN;1', rr_name='isolinux.bin')
iso.add_file(ldlinux_c32, '/ISOLINUX/LDLINUX.C32;1', rr_name='ldlinux.c32')

# Write isolinux.cfg with auto-boot and serial fallback option
cfg_content = b"""DEFAULT linux
PROMPT 0
TIMEOUT 10

LABEL linux
  MENU LABEL Nano Alpine Linux (VGA Console)
  KERNEL /bzImage
  INITRD /initrd.cpio.xz
  APPEND console=tty0 quiet

LABEL serial
  MENU LABEL Nano Alpine Linux (Serial Console)
  KERNEL /bzImage
  INITRD /initrd.cpio.xz
  APPEND console=ttyS0,115200 quiet
"""
iso.add_fp(io.BytesIO(cfg_content), len(cfg_content), '/ISOLINUX/ISOLINUX.CFG;1', rr_name='isolinux.cfg')

# Add kernel and initrd in ISO root
iso.add_file(bzimage_path, '/BZIMAGE.;1', rr_name='bzImage')
iso.add_file(initrd_path, '/INITRD.XZ;1', rr_name='initrd.cpio.xz')

# Add El Torito boot entry using isolinux.bin
iso.add_eltorito('/ISOLINUX/ISOLINUX.BIN;1', bootcatfile='/ISOLINUX/BOOT.CAT;1', boot_info_table=True)

# Write ISO file
iso.write(output_iso_path)
iso.close()

print(f"ISO successfully created: {output_iso_path}")
