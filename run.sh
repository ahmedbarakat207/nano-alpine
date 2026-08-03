#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f linux.iso ]; then
    echo "linux.iso not found. Building ISO now..."
    ./build.sh
fi

if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "Error: qemu-system-x86_64 is not installed."
    echo "Please install QEMU (e.g. sudo apt-get install qemu-system-x86)"
    exit 1
fi

MODE="gui"
if [ "$1" = "--nographic" ] || [ "$1" = "-n" ] || [ -z "$DISPLAY" ]; then
    MODE="serial"
fi

if [ "$MODE" = "serial" ]; then
    echo "Launching Nano-Alpine in QEMU Serial Console mode (Press Ctrl+A then X to exit)..."
    exec qemu-system-x86_64 -cdrom linux.iso -nographic -m 128M
else
    echo "Launching Nano-Alpine in QEMU Graphical Display mode..."
    exec qemu-system-x86_64 -cdrom linux.iso -m 128M
fi
