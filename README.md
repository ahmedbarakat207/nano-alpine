# Nano-Alpine Linux

Nano-Alpine is a minimalist, architecture-aware Linux distribution and bootable system featuring a custom two-stage MBR/El-Torito bootloader written in x86 assembly, a compact BusyBox userspace, and a zero-dependency POSIX shell package manager (`apk`). It is engineered for low-latency booting and minimal memory consumption across `i386` (32-bit) and `x86_64` (64-bit) architectures.

---

## Technical Specifications

| Component / Property | i386 (32-bit) Target | x86_64 (64-bit) Target |
| :--- | :--- | :--- |
| **Kernel Binary** | `bzImage_i386` (Linux 7.1.6, 852,480 B) | `bzImage` (Linux 7.1.6, 979,968 B) |
| **Initramfs Archive** | `initrd.cpio.xz` (~580 KB) | `initrd.cpio.xz` (~615 KB) |
| **Raw Disk Image** | `nano_i386.img` (1.41 MiB / 1.44 MB Floppy) | `nano_x86_64.img` (1.54 MiB / 1.61 MB Raw Disk) |
| **ISO Boot Image** | `linux_i386.iso` (1.50 MiB) | `linux.iso` (1.68 MiB) |
| **Console Output** | Dual-console (`console=ttyS0,115200 console=tty0`) | Dual-console (`console=ttyS0,115200 console=tty0`) |

---

## Bootloader Architecture & Memory Model

Nano-Alpine eliminates third-party bootloaders (such as ISOLINUX or GRUB) in favor of a custom 16-bit real/unreal mode NASM bootloader.

```text
Address               Component                     Description
-----------------------------------------------------------------------------------------------
0x0000:0x0000         Interrupt Vector Table        Real Mode IVT
0x0000:0x0600         Stage 2 Loader                4-sector Unreal Mode loader (2 KB)
0x0000:0x7C00         Stage 1 MBR                   Primary 512-byte boot sector
0x1000:0x0000         Bounce Buffer                 64 KB low-memory sector transfer buffer
0x9000:0x0000         Linux Kernel Setup            Kernel setup sectors and boot protocol header
0x9800:0x0000         Kernel Command Line           Command line string buffer
0x00100000 (1 MiB)    Kernel Payload (`bzImage`)    32-bit flat memory copy target
0x02000000 (32 MiB)   Initramfs (`initrd.cpio.xz`)  32-bit flat memory copy target
```

### 1. Stage 1 MBR (`bootloader/stage1_*.asm`)
- Executed at `0x0000:0x7C00` (sector 0) with trailing signature `0xAA55`.
- Performs drive geometry detection (`INT 13h, AH=08h`) to query Sectors Per Track (`SPT`) and Head count.
- Reads Stage 2 (4 sectors) from LBA 1 into `0x0000:0x0600` via CHS/EDD LBA routines and transfers execution.

### 2. Stage 2 Loader (`bootloader/stage2_*.asm`)
- Enables Fast A20 gate via system control port `0x92`.
- Initializes 80x25 VGA text mode (`INT 10h, AH=00h, AL=03h`) and displays centered splash text.
- Updates loading indicator via direct Video RAM writes (`0xB800:2320`), avoiding BIOS interrupt overhead during sector reads.
- Enters Unreal Mode via temporary Protected Mode transition (`cr0` bit 0) with a 4GB Data Segment descriptor (`0x08` selector in GDT), enabling 32-bit flat memory addressing in Real Mode.
- Reads setup sectors into `0x9000:0000`, copies kernel payload to 1 MiB (`0x00100000`), and initramfs to 32 MiB (`0x02000000`).
- Patches Linux 16-bit Boot Protocol header parameters (`ramdisk_image`, `ramdisk_size`, `cmd_line_ptr`, `type_of_loader`) and jumps to `0x9020:0000`.

### 3. Image Assembly Utilities
- **`bootloader/patch_lba.py`**: Computes sector counts and patches `initrd_start_lba` and `initrd_size_sectors` into Stage 2 binaries before generating raw disk images.
- **`make_iso.py`**: Generates El-Torito bootable ISO images (`pycdlib`) configured with floppy emulation or no-emulation mode based on image geometry.

---

## Directory Structure

```text
.
├── bootloader/
│   ├── stage1_i386.asm     # 32-bit Stage 1 MBR loader
│   ├── stage1_x86_64.asm   # 64-bit Stage 1 MBR loader
│   ├── stage2_i386.asm     # 32-bit Stage 2 Unreal Mode loader
│   ├── stage2_x86_64.asm   # 64-bit Stage 2 Unreal Mode loader
│   └── patch_lba.py        # LBA patcher and disk image assembler
├── rootfs/                 # 64-bit root filesystem directory
│   ├── init                # Userspace init script
│   └── sbin/apk            # Package manager implementation
├── rootfs_i386/            # 32-bit root filesystem directory
│   ├── init                # Userspace init script
│   └── sbin/apk            # Package manager implementation
├── build.sh                # Automated build pipeline script
├── run.sh                  # Execution script for QEMU testing
├── make_iso.py             # El-Torito ISO image builder
├── kernel.config           # 64-bit kernel configuration
└── kernel_i386.config      # 32-bit kernel configuration
```

---

## Build System

### Prerequisites

- NASM (Netwide Assembler)
- QEMU (`qemu-system-x86`)
- `cpio`, `xz-utils`
- Python 3 with `pycdlib`

### Compilation Commands

```bash
# Build 64-bit target (nano_x86_64.img and linux.iso)
./build.sh x86_64

# Build 32-bit target (nano_i386.img and linux_i386.iso)
./build.sh i386

# Clean build artifacts
./build.sh clean
```

---

## Execution

```bash
# Launch 64-bit in GUI window mode
./run.sh x86_64

# Launch 64-bit in headless serial console mode
./run.sh x86_64 -n

# Launch 32-bit floppy emulation mode
./run.sh i386 -fda -n

# Direct QEMU invocation
qemu-system-x86_64 -cdrom linux.iso -m 128M -serial stdio
```

---

## Package Management Interface (`/sbin/apk`)

The root filesystem includes a shell implementation of the Alpine Package Keeper interface (`/sbin/apk`):

```bash
# Synchronize package database indices
apk update

# Search available repository packages
apk search <query>

# Install package and resolve dependencies
apk add <package_name>

# List installed packages
apk list

# Remove installed package database entry
apk del <package_name>
```

---

## License

Distributed under the MIT License.
