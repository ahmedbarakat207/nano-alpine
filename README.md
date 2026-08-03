# Nano Alpine Linux 🚀

A super minimalist, custom-built Linux distribution & ISO with interactive shell (`sh`) and a zero-dependency package manager (`apk`), optimized to run with minimal footprint.

## 📌 Features

- **Ultra Minimal Footprint**: Kernel (`bzImage`) + RootFS (`initrd.cpio.xz`) combined ~1.4 MB!
- **Bootloader Included**: Bootable ISO with **ISOLINUX 6.03** bootloader.
- **Custom Zero-Dependency Package Manager (`/sbin/apk`)**: Installs Alpine packages (`apk add neofetch`, `fastfetch`, etc.) over HTTP directly from Alpine mirrors.
- **Graphical & Serial Console Support**: Supports QEMU SDL window console (`console=tty0`) and serial (`ttyS0`).
- **Panic-Proof Init System**: Custom panic-safe `/init` script using `cttyhack`.

---

## 🛠 Project Structure

```text
.
├── build.sh          # One-click build script
├── make_iso.py       # El Torito ISO generator using pycdlib
├── kernel.config     # Optimized Linux kernel config
├── rootfs/           # Base root filesystem files
│   ├── init          # Panic-proof init script
│   ├── sbin/apk      # Zero-dependency APK package manager
│   └── etc/resolv.conf # Network DNS resolver setup
├── src/linux         # Linux kernel source (git submodule)
└── README.md
```

---

## 🚀 How to Build & Run

### Prerequisites
Install Python dependencies and QEMU:
```bash
pip install pycdlib
sudo apt-get install qemu-system-x86 cpio xz-utils
```

### 1. Build the ISO
Run the automated build script:
```bash
./build.sh
```

### 2. Run in QEMU (Graphical Window / SDL)
```bash
qemu-system-x86_64 -cdrom linux.iso -m 128M
```

### 3. Run in QEMU (Terminal / Serial Console)
```bash
qemu-system-x86_64 -cdrom linux.iso -nographic -m 128M
```

---

## 📦 Zero-Dependency Package Manager (`apk`)

Inside the booted system, you can use the lightweight `/sbin/apk` script:

```bash
# Add a package from Alpine repositories
apk add neofetch
apk add fastfetch

# List installed packages
apk list

# Remove a package
apk del neofetch
```

---

## 📄 License
MIT License.
