# Nano Alpine Linux 🚀

[![Build & Test](https://github.com/ahmedbarakat207/nano-alpine/actions/workflows/build.yml/badge.svg)](https://github.com/ahmedbarakat207/nano-alpine/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ISO Size](https://img.shields.io/badge/ISO%20Size-~1.8MB-brightgreen.svg)]()
[![Kernel](https://img.shields.io/badge/Kernel-Linux-blue.svg)]()

A minimalist, custom-built Linux distribution & bootable ISO image featuring an interactive BusyBox shell (`sh`) and a zero-dependency package manager (`apk`), optimized for near-instant boot and ultra-minimal memory footprint.

---

## 📌 Features

- **Ultra-Minimal Footprint**: Complete bootable ISO (~1.8 MB) containing custom Kernel (`bzImage`) + compressed RootFS (`initrd.cpio.xz`).
- **Standard Bootloader**: Powered by **ISOLINUX 6.03** bootloader supporting VGA and Serial consoles.
- **Zero-Dependency Package Manager (`/sbin/apk`)**: Installs Alpine Linux packages (`apk add neofetch`, `fastfetch`, etc.) directly from official Alpine v3.20 mirrors over HTTP with dependency handling.
- **Auto-Configuring Network**: Automatic loopback (`lo`) and Ethernet (`eth0`) DHCP/SLIRP initialization on boot for VM and QEMU environments.
- **Panic-Proof Init System**: Custom `/init` script using `cttyhack` ensuring shells restart cleanly upon exit without kernel panics.

---

## 🛠 Project Structure

```text
.
├── .github/workflows/
│   └── build.yml      # CI/CD automated build & QEMU boot test
├── build.sh           # Automated ISO & rootfs build script
├── run.sh             # Easy QEMU runner (GUI or Serial)
├── make_iso.py        # PyCdlib El Torito ISO generator
├── kernel.config      # Optimized Linux kernel config
├── rootfs/            # Base root filesystem files
│   ├── init           # Panic-proof init script & net launcher
│   ├── sbin/apk       # Lightweight zero-dependency APK package manager
│   └── etc/resolv.conf # Network DNS resolver setup
└── README.md
```

---

## 🚀 Quick Start & Building

### Prerequisites

Install build dependencies and QEMU:

```bash
# Ubuntu / Debian
sudo apt-get install -y qemu-system-x86 cpio xz-utils syslinux isolinux python3-pip

# Install Python ISO library
pip install pycdlib
```

### 1. Build the ISO

Run the automated one-click build script:

```bash
./build.sh
```

### 2. Run in QEMU

You can use the helper script `./run.sh`:

```bash
# Launch in Serial / Terminal mode (default if no display)
./run.sh --nographic

# Launch in Graphical Window mode (SDL / GTK)
./run.sh
```

Or run QEMU directly:

```bash
# Terminal / Serial Console
qemu-system-x86_64 -cdrom linux.iso -nographic -m 128M

# Graphical Window
qemu-system-x86_64 -cdrom linux.iso -m 128M
```

---

## 📦 Zero-Dependency Package Manager (`apk`)

Inside the booted Nano-Alpine system, use `/sbin/apk` to manage packages:

```bash
# Update package index from Alpine mirrors
apk update

# Search for a package
apk search neofetch

# Add a package (downloads package and dependencies from Alpine mirrors)
apk add neofetch
apk add fastfetch

# List installed packages
apk list

# Remove a package
apk del neofetch
```

---

## 📄 License

MIT License. Developed by [ahmedbarakat207](https://github.com/ahmedbarakat207).
