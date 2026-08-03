#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ARCH="x86_64"
QEMU_CMD="qemu-system-x86_64"
IMG_FILE="nano_x86_64.img"
ISO_FILE="linux.iso"
BOOT_MODE="drive"

for arg in "$@"; do
    if [ "$arg" = "i386" ] || [ "$arg" = "32" ] || [ "$arg" = "x86" ]; then
        ARCH="i386"
        QEMU_CMD="qemu-system-i386"
        IMG_FILE="nano_i386.img"
        ISO_FILE="linux_i386.iso"
    elif [ "$arg" = "--iso" ] || [ "$arg" = "-cdrom" ]; then
        BOOT_MODE="iso"
    elif [ "$arg" = "-fda" ] || [ "$arg" = "--floppy" ]; then
        BOOT_MODE="floppy"
    fi
done

if [ "$BOOT_MODE" = "iso" ]; then
    BOOT_FILE="$ISO_FILE"
    BOOT_FLAGS="-cdrom $ISO_FILE"
    if [ ! -f "$ISO_FILE" ]; then
        echo "$ISO_FILE missing, building now..."
        ./build.sh "$ARCH"
    fi
elif [ "$BOOT_MODE" = "floppy" ]; then
    BOOT_FILE="$IMG_FILE"
    BOOT_FLAGS="-fda $IMG_FILE -boot a"
    if [ ! -f "$IMG_FILE" ]; then
        echo "$IMG_FILE missing, building now..."
        ./build.sh "$ARCH"
    fi
else
    BOOT_FILE="$IMG_FILE"
    BOOT_FLAGS="-drive format=raw,file=$IMG_FILE"
    if [ ! -f "$IMG_FILE" ]; then
        echo "$IMG_FILE missing, building now..."
        ./build.sh "$ARCH"
    fi
fi

if ! command -v "$QEMU_CMD" &>/dev/null; then
    QEMU_CMD="qemu-system-x86_64"
fi

DISPLAY_MODE="gui"
for arg in "$@"; do
    if [ "$arg" = "--nographic" ] || [ "$arg" = "-n" ]; then
        DISPLAY_MODE="serial"
    fi
done

if [ "$DISPLAY_MODE" = "serial" ]; then
    echo "Launching Nano-Alpine ($ARCH) [$BOOT_FILE] in QEMU Serial Console mode (Press Ctrl+A then X to exit)..."
    exec "$QEMU_CMD" $BOOT_FLAGS -nographic -m 128M
else
    echo "Launching Nano-Alpine ($ARCH) [$BOOT_FILE] in QEMU Graphical Display mode..."
    exec "$QEMU_CMD" $BOOT_FLAGS -m 128M
fi
