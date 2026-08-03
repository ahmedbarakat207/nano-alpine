import io
import pycdlib

iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=True, rock_ridge='1.12')

# Create ISOLINUX directory
iso.add_directory('/ISOLINUX', rr_name='isolinux')

# Add bootloader files in isolinux directory
iso.add_file('/tmp/syslinux-6.03/bios/core/isolinux.bin', '/ISOLINUX/ISOLINUX.BIN;1', rr_name='isolinux.bin')
iso.add_file('/tmp/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32', '/ISOLINUX/LDLINUX.C32;1', rr_name='ldlinux.c32')

# Write isolinux.cfg with auto-boot (PROMPT 0, TIMEOUT 1) and VGA console (console=tty0)
cfg_content = b"""PROMPT 0
TIMEOUT 1
DEFAULT linux
LABEL linux
  KERNEL /bzImage
  INITRD /initrd.cpio.xz
  APPEND console=tty0 quiet
"""
iso.add_fp(io.BytesIO(cfg_content), len(cfg_content), '/ISOLINUX/ISOLINUX.CFG;1', rr_name='isolinux.cfg')

# Add kernel and initrd in root
iso.add_file('/home/ahmed/nano/bzImage', '/BZIMAGE.;1', rr_name='bzImage')
iso.add_file('/home/ahmed/nano/initrd.cpio.xz', '/INITRD.XZ;1', rr_name='initrd.cpio.xz')

# Add El Torito boot entry using isolinux.bin
iso.add_eltorito('/ISOLINUX/ISOLINUX.BIN;1', bootcatfile='/ISOLINUX/BOOT.CAT;1', boot_info_table=True)

# Write ISO file
iso.write('/home/ahmed/nano/linux.iso')
iso.close()
print("ISO successfully created!")
