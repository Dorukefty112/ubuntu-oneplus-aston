#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Set up dualboot: Android on slot A, Ubuntu on slot B.

Requirements:
  - Phone in bootloader mode (fastboot)
  - Unlocked bootloader
  - Stock Android working on slot A

Options:
  -r, --repartition     Create 'win' partition (WARNING: wipes Android data!)
  -f, --flash           Flash everything to slot B
  -a, --android-version VERSION  Android version: 14 or 15 (default: 14)
  -d, --dry-run         Print commands without executing
  -h, --help            Show this help

Examples:
  # Step 1: Repartition (run from TWRP or recovery with parted)
  $0 --repartition

  # Step 2: Flash Ubuntu to slot B
  $0 --flash -a 14
EOF
    exit 0
}

REPARTITION=false
FLASH=false
DRY_RUN=false
ANDROID_VER=14

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--repartition) REPARTITION=true; shift ;;
        -f|--flash) FLASH=true; shift ;;
        -a|--android-version) ANDROID_VER="$2"; shift 2 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

BOOT_IMG="boot16G_A14.img"
if [ "$ANDROID_VER" = "15" ]; then
    BOOT_IMG="boot16G.img"
fi

if [ ! -f "$SCRIPT_DIR/$BOOT_IMG" ]; then
    echo "Error: $BOOT_IMG not found. Build it first with aston-kernel_build.sh"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/rootfs.img" ]; then
    echo "Error: rootfs.img not found. Build it first with aston-rootfs_build.sh"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/vbmeta_b_disabled.img" ]; then
    echo "Error: vbmeta_b_disabled.img not found. Generate it with avbtool"
    echo "  avbtool make_vbmeta_image --algorithm NONE --flags 2 --output vbmeta_b_disabled.img"
    exit 1
fi

cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        echo "[RUN] $*"
        eval "$@"
    fi
}

if [ "$REPARTITION" = true ]; then
    echo "================================"
    echo " REPARTITIONING"
    echo " WARNING: This wipes Android data!"
    echo "================================"
    echo ""
    echo "Run these commands in TWRP terminal or ADB shell:"
    echo ""
    echo "  # Push parted to device"
    echo "  adb push parted /tmp/parted"
    echo "  adb shell chmod +x /tmp/parted"
    echo ""
    echo "  # Check current layout"
    echo "  adb shell /tmp/parted /dev/block/sda print"
    echo ""
    echo "  # Delete userdata, create smaller userdata + win"
    echo "  # Example: if userdata is 17GB-251GB:"
    echo "  adb shell /tmp/parted /dev/block/sda rm <userdata_num>"
    echo "  adb shell /tmp/parted /dev/block/sda mkpart userdata f2fs 17GB 181GB"
    echo "  adb shell /tmp/parted /dev/block/sda mkpart win ext4 181GB 251GB"
    echo ""
    echo "  # Format win partition"
    echo "  adb shell mkfs.ext4 /dev/block/by-name/win"
    echo ""
    echo "Adjust partition sizes based on your needs."
    exit 0
fi

if [ "$FLASH" = true ]; then
    echo "================================"
    echo " FLASHING UBUNTU TO SLOT B"
    echo "================================"

    echo ""
    echo "Step 1: Push rootfs to device"
    echo "  fastboot flash win rootfs.img"
    echo "  OR via TWRP:"
    echo "  adb push rootfs.img /tmp/"
    echo "  adb shell dd if=/tmp/rootfs.img of=/dev/block/by-name/win"
    echo ""

    cmd "fastboot flash win \"$SCRIPT_DIR/rootfs.img\"" || {
        echo "fastboot flash win failed, trying via dd..."
        echo "Boot into TWRP and run:"
        echo "  adb push \"$SCRIPT_DIR/rootfs.img\" /tmp/"
        echo "  adb shell dd if=/tmp/rootfs.img of=/dev/block/by-name/win"
    }

    echo ""
    echo "Step 2: Flash vbmeta_b with verification disabled"
    cmd "fastboot flash vbmeta_b \"$SCRIPT_DIR/vbmeta_b_disabled.img\""

    echo ""
    echo "Step 3: Flash boot image to boot_b"
    cmd "fastboot flash boot_b \"$SCRIPT_DIR/$BOOT_IMG\""

    echo ""
    echo "Step 4: Verify slot metadata"
    cmd "fastboot set_active b"
    cmd "fastboot reboot"

    echo ""
    echo "================================"
    echo " DONE! Phone should boot Ubuntu."
    echo "================================"
    echo ""
    echo "To switch back to Android:"
    echo "  fastboot set_active a && fastboot reboot"
    echo ""
    echo "To switch to Ubuntu again:"
    echo "  fastboot set_active b && fastboot reboot"
    echo ""
    echo "If Ubuntu doesn't boot:"
    echo "  1. Try booting with: fastboot boot $BOOT_IMG"
    echo "  2. If that works but flash doesn't: re-check vbmeta"
    echo "  3. If BCB is corrupted: adb shell dd if=/dev/zero of=/dev/block/by-name/misc"
    exit 0
fi

usage
