#!/bin/bash

# ==============================================================================
# "Kustom" Kernel Builder for Realme GT Neo 3T (SM8250-AC)
# Features: 
#   1. KernelSU v0.9.5 (Compatible with Kernel 4.19) + path_umount backport
#   2. Fixed Host Build Errors (.base64/libtinfo/.relr.dyn) on Arch Linux
#   3. ColorOS/OxygenOS Port Support (EROFS/F2FS)
#   4. Fixed 'get_cached_platform_id' error (Using correct <soc/qcom/socinfo.h>)
#   5. Fixed 'log_kpd_event' error by REWRITING the problematic file section
#   6. if you use other linux distro then paste your distro commands in the line 
#     35
#   7.If any problem occur then check the dtbo img line and also change the kernel
#     source with your device kernel and it works only sm8250 
# OS: Arch Linux rn so change the code i am bit lazy :/
# ==============================================================================

# 1. Error Handling
set -e

# 2. Variables
WORK_DIR="$HOME/android/kustom_kernel"
KERNEL_SOURCE="https://github.com/provasish/android_kernel_oneplus_sm8250.git"
TOOLCHAIN_SOURCE="https://github.com/kdrag0n/proton-clang.git"
ANYKERNEL_SOURCE="https://github.com/osm0sis/AnyKernel3.git"
DEFCONFIG="vendor/kona-perf_defconfig"
KERNEL_NAME="Kustom"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}>>> Starting Kustom Kernel Build (Port ROM Supported)...${NC}"

# 3. Install Arch Dependencies
echo -e "${BLUE}>>> Installing Arch Dependencies...${NC}"
sudo pacman -S --needed --noconfirm base-devel git bc python python-pip ncurses libxml2 xmlto inetutils cpio unzip rsync wget multilib-devel pahole

# 4. Setup Directories
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 5. Clone Sources
if [ ! -d "source" ]; then
    echo -e "${BLUE}>>> Cloning Kernel Source...${NC}"
    git clone --depth=1 "$KERNEL_SOURCE" source
else
    echo -e "${BLUE}>>> Kernel source exists.${NC}"
fi

if [ ! -d "clang" ]; then
    echo -e "${BLUE}>>> Cloning Proton Clang...${NC}"
    git clone --depth=1 "$TOOLCHAIN_SOURCE" clang
    
    # CRITICAL FIX for Arch Linux Host Compilation (Fixes .relr.dyn error)
    echo -e "${BLUE}>>> Fixing Toolchain Linker for Arch Linux...${NC}"
    rm -f clang/bin/ld
fi

if [ ! -d "AnyKernel3" ]; then
    echo -e "${BLUE}>>> Cloning AnyKernel3...${NC}"
    git clone "$ANYKERNEL_SOURCE" AnyKernel3
fi

# 6. Clean & Reset Source (Fixes "file not found" loops)
cd source
echo -e "${BLUE}>>> Cleaning source tree...${NC}"
git reset --hard HEAD
git clean -fdx

# 7. KernelSU Integration
echo -e "${BLUE}>>> Patching KernelSU (v0.9.5)...${NC}"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5

# 7.1 Backport path_umount
if ! grep -q "path_umount" fs/namespace.c; then
    echo -e "${BLUE}>>> Backporting path_umount to fs/namespace.c...${NC}"
    cat <<EOF >> fs/namespace.c

// KernelSU Backport: path_umount
int path_umount(struct path *path, int flags)
{
	return do_umount(path->mnt, flags);
}
EXPORT_SYMBOL_GPL(path_umount);
EOF
fi

# 8. Fix Compilation Errors (Source Code Patching)
echo -e "${BLUE}>>> Patching Source Code Errors...${NC}"

# Fix 1: 'get_cached_platform_id' error
if [ -f "include/soc/qcom/socinfo.h" ]; then
    sed -i '1i #include <soc/qcom/socinfo.h>' drivers/irqchip/irq-gic-v3.c
    echo -e "${GREEN}Fixed irq-gic-v3.c header include.${NC}"
else
    sed -i '1i #include <linux/soc/qcom/socinfo.h>' drivers/irqchip/irq-gic-v3.c
fi

# Fix 2: 'no member named log_kpd_event' in qpnp-power-on.c
# We forcefully disable the logging logic by commenting out the variable usage.
# This is more robust than trying to patch the struct.
echo -e "${GREEN}Disabling broken logging in qpnp-power-on.c...${NC}"
sed -i 's/pon->log_kpd_event/false/g' drivers/input/misc/qpnp-power-on.c

# 9. Configure Kernel
echo -e "${BLUE}>>> Configuring Kernel...${NC}"
CLANG_PATH="$WORK_DIR/clang/bin"

# Load Defconfig
make O=out ARCH=arm64 "$DEFCONFIG"

# --- CUSTOMIZATION ---
CONFIG_FILE="out/.config"

# A. Branding
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-Kustom"/' "$CONFIG_FILE" || echo 'CONFIG_LOCALVERSION="-Kustom"' >> "$CONFIG_FILE"

# B. KernelSU Requirements
./scripts/config --file "$CONFIG_FILE" \
    --enable KPROBES \
    --enable HAVE_KPROBES \
    --enable KPROBE_EVENTS \
    --enable OVERLAY_FS

# C. Port ROM Support
./scripts/config --file "$CONFIG_FILE" \
    --enable EROFS_FS \
    --enable EROFS_FS_ZIPFLT \
    --enable F2FS_FS \
    --enable EXFAT_FS \
    --enable NTFS_FS

# D. Balanced Tuning (Disable Debugging)
./scripts/config --file "$CONFIG_FILE" \
    --enable CPU_FREQ_GOV_SCHEDUTIL \
    --set-val HZ 300 \
    --disable PAGE_EXTENSION \
    --disable DEBUG_PAGEALLOC \
    --disable DEBUG_PANIC_ON_OOM \
    --disable PAGE_POISONING \
    --disable DEBUG_PAGE_REF \
    --disable DEBUG_RODATA_TEST \
    --disable DEBUG_OBJECTS \
    --disable SLUB_STATS \
    --disable DEBUG_KMEMLEAK \
    --disable DEBUG_STACK_USAGE \
    --disable DEBUG_VM \
    --disable DEBUG_VIRTUAL \
    --disable DEBUG_MEMORY_INIT \
    --disable DEBUG_PER_CPU_MAPS \
    --disable KASAN \
    --disable KASAN_STACK_ENABLE \
    --disable DEBUG_KERNEL \
    --disable DEBUG_INFO \
    --disable SLUB_DEBUG \
    --disable CORESIGHT \
    --disable WERROR

# Update config non-interactively
make O=out ARCH=arm64 olddefconfig

# 10. Compile
echo -e "${BLUE}>>> Compiling...${NC}"

# KCFLAGS="-w" suppresses all warnings so they don't become errors
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    CC="$CLANG_PATH/clang" \
    LD="$CLANG_PATH/ld.lld" \
    AR="$CLANG_PATH/llvm-ar" \
    NM="$CLANG_PATH/llvm-nm" \
    OBJCOPY="$CLANG_PATH/llvm-objcopy" \
    OBJDUMP="$CLANG_PATH/llvm-objdump" \
    STRIP="$CLANG_PATH/llvm-strip" \
    HOSTCC=gcc \
    HOSTCXX=g++ \
    HOSTCFLAGS="-g0" \
    KCFLAGS="-w -Wno-error" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    Image

# 11. Packaging (Using your Custom AnyKernel3 Config + dtbo.img + ak3-core.sh)
echo -e "${BLUE}>>> Packaging...${NC}"
if [ -f "out/arch/arm64/boot/Image" ]; then
    cd "$WORK_DIR/AnyKernel3"
    git checkout . 
    git clean -fdx

    # Create anykernel.sh based on your uploaded file
    cat <<EOF > anykernel.sh
### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# begin properties
properties() { '
kernel.string=Kustom Kernel (Built by Gemini)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=RMX3371
device.name2=RE54E4L1
device.name3=spartan
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

### AnyKernel install
# begin attributes
attributes() {
set_perm_recursive 0 0 755 644 \$ramdisk/*;
set_perm_recursive 0 0 750 750 \$ramdisk/init* \$ramdisk/sbin;
} # end attributes

## boot shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

# import functions/variables and setup patching
. tools/ak3-core.sh && attributes;

# boot install
dump_boot;
flash_dtbo; # Flashes dtbo.img if present in zip
vbmeta_disable_verification;
write_boot;
EOF

    # Copy the compiled Image
    cp "$WORK_DIR/source/out/arch/arm64/boot/Image" .
    
    # Copy your custom dtbo.img if it exists in the WORK_DIR
    if [ -f "$WORK_DIR/dtbo.img" ]; then
        echo -e "${GREEN}Found custom dtbo.img, including in zip...${NC}"
        cp "$WORK_DIR/dtbo.img" .
    else
        echo -e "${RED}No dtbo.img found in $WORK_DIR. Make sure you uploaded it there.${NC}"
    fi

    # Copy your custom ak3-core.sh if it exists in the WORK_DIR
    if [ -f "$WORK_DIR/ak3-core.sh" ]; then
        echo -e "${GREEN}Found custom ak3-core.sh, updating tools...${NC}"
        cp "$WORK_DIR/ak3-core.sh" tools/
        chmod +x tools/ak3-core.sh
    else
        echo -e "${RED}No ak3-core.sh found in $WORK_DIR. Using default.${NC}"
    fi

    # Zip it
    zip -r9 "$WORK_DIR/Kustom-Kernel-GTNeo3T-KSU.zip" * -x .git README.md *placeholder
    
    echo -e "${GREEN}SUCCESS! Zip located at: $WORK_DIR/Kustom-Kernel-GTNeo3T-KSU.zip${NC}"
else
    echo -e "${RED}ERROR: Compilation failed, Image not found.${NC}"
    exit 1
fi
