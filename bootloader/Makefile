# Makefile for Nano-Alpine bootloader
# Requires: nasm, dd, python3
#
# Usage:
#   make              - Build both bootloaders
#   make x86_64       - Build x86_64 boot binary
#   make i386         - Build i386 boot binary
#   make disk_x86_64  - Build raw bootable disk image (x86_64)
#   make disk_i386    - Build raw bootable disk image (i386)
#   make clean        - Remove build artifacts

NASM    = nasm
PYTHON  = python3
SCRIPT  = ../bootloader/patch_lba.py

.PHONY: all x86_64 i386 disk_x86_64 disk_i386 clean

all: x86_64 i386

x86_64: boot_x86_64.bin

i386: boot_i386.bin

boot_x86_64.bin: boot_x86_64.asm
	$(NASM) -f bin -o $@ $<
	@echo "[x86_64] Assembled: $@ ($$(wc -c < $@) bytes)"

boot_i386.bin: boot_i386.asm
	$(NASM) -f bin -o $@ $<
	@echo "[i386] Assembled: $@ ($$(wc -c < $@) bytes)"

# Build a raw disk image: bootloader + kernel + initrd
# Run from project root: make -C bootloader disk_x86_64
disk_x86_64: boot_x86_64.bin
	$(PYTHON) patch_lba.py \
		--boot boot_x86_64.bin \
		--kernel ../bzImage \
		--initrd ../initrd.cpio.xz \
		--output ../nano_x86_64.img
	@echo "[x86_64] Raw disk image: nano_x86_64.img"

disk_i386: boot_i386.bin
	$(PYTHON) patch_lba.py \
		--boot boot_i386.bin \
		--kernel ../bzImage_i386 \
		--initrd ../initrd.cpio.xz \
		--output ../nano_i386.img
	@echo "[i386] Raw disk image: nano_i386.img"

clean:
	rm -f boot_x86_64.bin boot_i386.bin *.img
