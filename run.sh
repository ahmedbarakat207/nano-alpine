#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ARCH="x86_64"
QEMU_CMD="qemu-system-x86_64"
ISO_FILE="linux.iso"

if [ "$1" = "i386" ] || [ "$1" = "32" ] || [ "$2" = "i386" ]; then
    ARCH="i386"
    QEMU_CMD="qemu-system-i386"
    ISO_FILE="linux_i386.iso"
    [ ! -f "$ISO_FILE" ] && ISO_FILE="linux.iso"
fi

if [ ! -f "$ISO_FILE" ]; then
    echo "$ISO_FILE not found. Building ISO now..."
    ./build.sh "$ARCH"
fi

if ! command -v "$QEMU_CMD" &>/dev/null; then
    QEMU_CMD="qemu-system-x86_64"
fi

MODE="gui"
for arg in "$@"; do
    if [ "$arg" = "--nographic" ] || [ "$arg" = "-n" ]; then
        MODE="serial"
    fi
done

if [ "$MODE" = "serial" ]; then
    echo "Launching Nano-Alpine ($ARCH) in QEMU Serial Console mode (Press Ctrl+A then X to exit)..."
    exec "$QEMU_CMD" -cdrom "$ISO_FILE" -nographic -m 128M
else
    echo "Launching Nano-Alpine ($ARCH) in QEMU Graphical Display mode..."
    exec "$QEMU_CMD" -cdrom "$ISO_FILE" -m 128M
fi
