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

# 2. Download Alpine Linux Mini RootFS if missing
ALPINE_TAR=$(ls alpine-minirootfs-*.tar.gz 2>/dev/null | head -n1)
if [ -z "$ALPINE_TAR" ]; then
    echo "Downloading Alpine Linux Mini RootFS..."
    ALPINE_TAR="alpine-minirootfs-3.20.3-x86_64.tar.gz"
    curl -sSL -o "$ALPINE_TAR" "http://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/$ALPINE_TAR"
fi

# 3. Prepare RootFS using Alpine minirootfs base
echo "Preparing Alpine static rootfs..."
rm -rf static_rootfs
mkdir -p static_rootfs
tar -xzf "$ALPINE_TAR" -C static_rootfs

# Copy custom init, apk package manager, and resolv.conf overlay
cp rootfs/init static_rootfs/init
cp rootfs/sbin/apk static_rootfs/sbin/apk
cp rootfs/etc/resolv.conf static_rootfs/etc/resolv.conf
chmod +x static_rootfs/init static_rootfs/sbin/apk

# Ensure busybox symlinks for cttyhack if missing
if [ -f static_rootfs/bin/busybox ] && [ ! -e static_rootfs/bin/cttyhack ]; then
    ln -s busybox static_rootfs/bin/cttyhack 2>/dev/null || true
fi

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
