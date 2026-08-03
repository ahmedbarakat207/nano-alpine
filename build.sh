#!/bin/bash
set -e

echo "=== Building Nano-Alpine Minimal Linux ISO ==="

# 1. Download Static Busybox if missing
if [ ! -f busybox-static ]; then
    echo "Downloading static busybox..."
    curl -sSL -o busybox-static https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x busybox-static
fi

# 2. Prepare RootFS
echo "Preparing static rootfs..."
rm -rf static_rootfs
mkdir -p static_rootfs/{bin,dev,etc,proc,sys,tmp,sbin,usr/bin,usr/sbin,var/lib/apk_mini}

cp busybox-static static_rootfs/bin/busybox
chmod +x static_rootfs/bin/busybox
cp rootfs/init static_rootfs/init
cp rootfs/sbin/apk static_rootfs/sbin/apk
cp rootfs/etc/resolv.conf static_rootfs/etc/resolv.conf
chmod +x static_rootfs/init static_rootfs/sbin/apk

# Symlink core shell tools
cd static_rootfs/bin
for app in sh ls cat echo cp mv rm mkdir rmdir mount umount ps kill vi tar gzip gunzip zcat grep egrep fgrep sed awk wget ping cttyhack clear dmesg reboot halt poweroff touch chmod chown find xargs head tail wc cut tr uniq sort env pwd uname hostname id whoami date uptime sleep sync; do
    ln -s busybox $app 2>/dev/null || true
done

cd ../..

# 3. Compress initrd
echo "Compressing initramfs (XZ)..."
cd static_rootfs
find . -print0 | cpio --null -ov --format=newc | xz -9 --extreme --check=crc32 > ../initrd.cpio.xz
cd ..

# 4. Download syslinux bootloader files if missing
if [ ! -d /tmp/syslinux-6.03 ]; then
    echo "Fetching syslinux ISOLINUX binaries..."
    curl -sSL -o /tmp/syslinux.tar.xz https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
    tar -xf /tmp/syslinux.tar.xz -C /tmp syslinux-6.03/bios/core/isolinux.bin syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 2>/dev/null || true
fi

# 5. Build ISO
echo "Generating bootable ISO image..."
python3 make_iso.py

echo "=== Build Complete ==="
ls -lh bzImage initrd.cpio.xz linux.iso
