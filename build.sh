#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$1" = "clean" ] || [ "$1" = "--clean" ]; then
    echo "Cleaning build artifacts..."
    rm -rf .syslinux initrd.cpio.xz linux.iso linux_i386.iso *.log
    echo "Clean complete."
    exit 0
fi

# Detect Target Architecture
TARGET_ARCH="${ARCH:-x86_64}"
if [ "$1" = "i386" ] || [ "$1" = "x86" ] || [ "$1" = "32" ]; then
    TARGET_ARCH="i386"
elif [ "$1" = "x86_64" ] || [ "$1" = "amd64" ] || [ "$1" = "64" ]; then
    TARGET_ARCH="x86_64"
fi

echo "=== Building Nano-Alpine Minimal Linux ISO (${TARGET_ARCH}) ==="

BZIMAGE_FILE="bzImage"
CONFIG_FILE="kernel.config"
BUSYBOX_URL="https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
OUTPUT_ISO="linux.iso"
ROOTFS_DIR="rootfs"

if [ "$TARGET_ARCH" = "i386" ]; then
    BZIMAGE_FILE="bzImage_i386"
    CONFIG_FILE="kernel_i386.config"
    BUSYBOX_URL="https://busybox.net/downloads/binaries/1.35.0-i686-linux-musl/busybox"
    OUTPUT_ISO="linux_i386.iso"
    ROOTFS_DIR="rootfs_i386"
fi

# 1. Ensure kernel bzImage is present
if [ ! -f "$BZIMAGE_FILE" ]; then
    echo "$BZIMAGE_FILE missing, checking kernel source..."
    if [ -f linux-7.1.6/arch/x86/boot/bzImage ]; then
        cp linux-7.1.6/arch/x86/boot/bzImage "$BZIMAGE_FILE"
    else
        if [ ! -d linux-7.1.6 ]; then
            echo "Downloading Linux 7.1.6 kernel source..."
            curl -sSL -o linux-7.1.6.tar.xz https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.6.tar.xz
            tar -xf linux-7.1.6.tar.xz
            rm -f linux-7.1.6.tar.xz
        fi

        if [ -f "$CONFIG_FILE" ]; then
            echo "Applying $CONFIG_FILE to linux-7.1.6/.config..."
            cp "$CONFIG_FILE" linux-7.1.6/.config
        fi

        echo "Building kernel $BZIMAGE_FILE for $TARGET_ARCH from linux-7.1.6..."
        make -C linux-7.1.6 ARCH="$TARGET_ARCH" olddefconfig 2>/dev/null || true
        make -C linux-7.1.6 ARCH="$TARGET_ARCH" -j$(nproc) bzImage
        cp linux-7.1.6/arch/x86/boot/bzImage "$BZIMAGE_FILE"
    fi
fi

# 2. Ensure rootfs directory is present; download release fallback tarball if missing
if [ ! -d "$ROOTFS_DIR" ] || [ ! -f "$ROOTFS_DIR/init" ]; then
    if [ "$TARGET_ARCH" = "i386" ] && [ -d rootfs ]; then
        echo "Creating rootfs_i386/ from rootfs/..."
        cp -a rootfs "$ROOTFS_DIR"
    else
        echo "$ROOTFS_DIR missing, downloading release fallback rootfs.tar..."
        curl -sSL -o rootfs.tar https://github.com/ahmedbarakat207/nano-alpine/releases/download/1.8mb/rootfs.tar
        tar -xf rootfs.tar
        rm -f rootfs.tar
        if [ "$ROOTFS_DIR" = "rootfs_i386" ]; then
            cp -a rootfs "$ROOTFS_DIR"
        fi
    fi
fi

# 3. Ensure arch-appropriate busybox is present in $ROOTFS_DIR/bin/busybox
if [ ! -f "$ROOTFS_DIR/bin/busybox" ]; then
    echo "Downloading $TARGET_ARCH static busybox into $ROOTFS_DIR/bin/busybox..."
    mkdir -p "$ROOTFS_DIR/bin"
    curl -sSL -o "$ROOTFS_DIR/bin/busybox" "$BUSYBOX_URL"
    chmod +x "$ROOTFS_DIR/bin/busybox"
fi

# Ensure permissions
chmod +x "$ROOTFS_DIR/init" "$ROOTFS_DIR/sbin/apk" "$ROOTFS_DIR/usr/bin/neofetch" "$ROOTFS_DIR/bin/busybox" 2>/dev/null || true

# 4. Compress rootfs initramfs (XZ)
echo "Compressing initramfs from $ROOTFS_DIR/..."
cd "$ROOTFS_DIR"
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
echo "Generating bootable ISO image ($OUTPUT_ISO)..."
KERNEL_BIN="$BZIMAGE_FILE" python3 make_iso.py

if [ "$OUTPUT_ISO" != "linux.iso" ] && [ -f linux.iso ]; then
    mv linux.iso "$OUTPUT_ISO"
fi

echo "=== Build Complete (${TARGET_ARCH}) ==="
ls -lh "$BZIMAGE_FILE" initrd.cpio.xz "$OUTPUT_ISO"
