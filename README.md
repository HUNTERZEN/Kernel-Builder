# 🛠️ Kernel Builder — SM8250 Edition

![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey?style=for-the-badge&logo=linux)
![Target](https://img.shields.io/badge/Target-SM8250-blue?style=for-the-badge&logo=qualcomm)
![Focus](https://img.shields.io/badge/Focus-Performance-orange?style=for-the-badge)

A powerful, automated shell script designed to compile custom kernels for **SM8250 (Snapdragon 865/870)** devices. This tool streamlines the entire build process—from setting up the toolchain to generating a flashable `.zip` file—optimized for speed and reliability.

---

## ⚡ Core Features

* **🚀 Automated Build Flow:** One-click script to handle environment setup, defconfig, and compilation.
* **🔧 Toolchain Support:** Pre-configured for **Clang** (AOSP/Proton) and **GCC** cross-compilation.
* **🛡️ KSU Integration:** Built-in support for patching **KernelSU** (KSU) directly during the build process.
* **🏎️ High-Performance Defaults:** Optimized for SM8250 targets to ensure stable and fast kernel execution.
* **📦 AnyKernel3 Ready:** Automatically packages the compiled `Image.gz-dtb` into a flashable AnyKernel3 zip.
* **🧹 Clean Management:** Dedicated functions to clean build artifacts and manage output logs.

---

## 🧩 Compatibility

| Component | Requirement |
| :--- | :--- |
| **Target SoC** | SM8250 (Snapdragon 865 / 865+ / 870) |
| **Build OS** | Arch Linux (Preferred) or Ubuntu |
| **Compiler** | AOSP Clang / Proton Clang |
| **Dependencies** | `bc`, `bison`, `flex`, `git`, `make`, `python3` |

---

## ⚠️ Important Disclaimer

> [!CAUTION]
> **Performance Focus:** This script is optimized for performance-oriented kernels. Improper configuration of the kernel source can lead to hardware instability. Use at your own risk.

---

## 🛠️ Usage

1. **Clone the Builder:**
   ```bash
   git clone [https://github.com/HUNTERZEN/kernel_builder.git](https://github.com/HUNTERZEN/kernel_builder.git)
   cd kernel_builder
