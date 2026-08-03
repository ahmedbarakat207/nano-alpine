# Makefile for Nano-Alpine Two-Stage MBR Bootloader
# Requires: nasm, python3

NASM    = nasm
PYTHON  = python3
SCRIPT  = patch_lba.py

.PHONY: all x86_64 i386 disk_x86_64 disk_i386 clean

all: x86_64 i386

x86_64: stage1_x86_64.bin stage2_x86_64.bin

i386: stage1_i386.bin stage2_i386.bin

stage1_x86_64.bin: stage1_x86_64.asm
	$(NASM) -f bin -o $@ $<

stage2_x86_64.bin: stage2_x86_64.asm
	$(NASM) -f bin -l stage2_x86_64.lst -o $@ $<

stage1_i386.bin: stage1_i386.asm
	$(NASM) -f bin -o $@ $<

stage2_i386.bin: stage2_i386.asm
	$(NASM) -f bin -l stage2_i386.lst -o $@ $<

disk_x86_64: x86_64
	$(PYTHON) $(SCRIPT) --arch x86_64 --output ../nano_x86_64.img
	@echo "[x86_64] Raw disk image: nano_x86_64.img"

disk_i386: i386
	$(PYTHON) $(SCRIPT) --arch i386 --output ../nano_i386.img
	@echo "[i386] Raw disk image: nano_i386.img"

clean:
	rm -f *.bin *.lst
