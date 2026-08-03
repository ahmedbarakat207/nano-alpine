#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building Nano-Alpine Minimal Linux ISO ==="

# 1. Ensure kernel bzImage is present
if [ ! -f bzImage ]; then
    echo "bzImage missing, checking kernel sources..."
    if [ -f linux-7.1.6/arch/x86/boot/bzImage ]; then
        cp linux-7.1.6/arch/x86/boot/bzImage bzImage
    elif [ -f src/linux/arch/x86/boot/bzImage ]; then
        cp src/linux/arch/x86/boot/bzImage bzImage
    elif [ -d linux-7.1.6 ]; then
        echo "Building kernel bzImage from linux-7.1.6..."
        make -C linux-7.1.6 -j$(nproc) bzImage
        cp linux-7.1.6/arch/x86/boot/bzImage bzImage
    else
        echo "Error: bzImage not found and no kernel source available to compile."
        exit 1
    fi
fi

# 2. Download Static Busybox if missing
if [ ! -f busybox-static ]; then
    echo "Downloading static busybox..."
    curl -sSL -o busybox-static https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x busybox-static
fi

# 3. Prepare RootFS using custom rootfs/ files
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
for app in sh ls cat echo cp mv rm mkdir rmdir mount umount ps kill vi tar gzip gunzip zcat grep egrep fgrep sed awk wget ping cttyhack clear dmesg reboot halt poweroff touch chmod chown find xargs head tail wc cut tr uniq sort env pwd uname hostname id whoami date uptime sleep sync ip ifconfig udhcpc route; do
    ln -s busybox $app 2>/dev/null || true
done
cd "$SCRIPT_DIR"

# 4. Compress initramfs
echo "Compressing initramfs (XZ)..."
cd static_rootfs
find . -print0 | cpio --null -ov --format=newc | xz -9 --extreme --check=crc32 > ../initrd.cpio.xz
cd "$SCRIPT_DIR"

# 5. Download syslinux bootloader files locally if not present in system or local cache
mkdir -p .syslinux
if [ ! -f .syslinux/isolinux.bin ] || [ ! -f .syslinux/ldlinux.c32 ]; then
    if [ -f /usr/lib/ISOLINUX/isolinux.bin ] && [ -f /usr/lib/syslinux/modules/bios/ldlinux.c32 ]; then
        echo "Using system ISOLINUX bootloader files..."
    else
        echo "Fetching syslinux ISOLINUX binaries into local cache..."
        TMP_TAR="/tmp/syslinux.tar.xz"
        curl -sSL -o "$TMP_TAR" https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
        tar -xf "$TMP_TAR" -C .syslinux --strip-components=4 syslinux-6.03/bios/core/isolinux.bin syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 2>/dev/null || true
        rm -f "$TMP_TAR"
    fi
fi

# 6. Build ISO
echo "Generating bootable ISO image..."
python3 make_iso.py

echo "=== Build Complete ==="
ls -lh bzImage initrd.cpio.xz linux.iso
