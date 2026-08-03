#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$1" = "clean" ] || [ "$1" = "--clean" ]; then
    echo "Cleaning build artifacts..."
    rm -rf .syslinux initrd.cpio.xz linux.iso *.log
    echo "Clean complete."
    exit 0
fi

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

# 2. Ensure rootfs/ is present; download official fallback tarball if missing
if [ ! -d rootfs ] || [ ! -f rootfs/init ]; then
    echo "rootfs/ missing, downloading release fallback rootfs.tar..."
    curl -sSL -o rootfs.tar https://github.com/ahmedbarakat207/nano-alpine/releases/download/1.8mb/rootfs.tar
    tar -xf rootfs.tar
    rm -f rootfs.tar
fi

# 3. Ensure busybox is present in rootfs/bin/busybox
if [ ! -f rootfs/bin/busybox ]; then
    echo "Downloading static busybox into rootfs/bin/busybox..."
    mkdir -p rootfs/bin
    curl -sSL -o rootfs/bin/busybox https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x rootfs/bin/busybox
fi

# Ensure permissions
chmod +x rootfs/init rootfs/sbin/apk rootfs/usr/bin/neofetch rootfs/bin/busybox 2>/dev/null || true

# 4. Compress rootfs initramfs (XZ)
echo "Compressing initramfs from rootfs/..."
cd rootfs
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
