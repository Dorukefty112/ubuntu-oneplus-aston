#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Extract OnePlus 12R firmware blobs and build firmware packages.

Options:
  -d, --device          Extract firmware from device via ADB
  -z, --zip FILE        Extract firmware from stock OxygenOS ZIP
  -f, --firmware-dir DIR  Use already-extracted firmware directory
  -o, --output DIR      Output directory (default: current dir)
  -a, --android-version VERSION  Android version: 14 or 15 (default: 14)
  -h, --help            Show this help

Examples:
  $0 --device -a 14
  $0 --zip ~/Downloads/OnePlus-12R-CPH2609.zip -a 14
  $0 --firmware-dir ~/extracted_fw -a 14
EOF
    exit 0
}

ANDROID_VER=14
OUTPUT_DIR="$(pwd)"
FW_ZIP=""
FW_DIR=""
EXTRACT_DEVICE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device) EXTRACT_DEVICE=true; shift ;;
        -z|--zip) FW_ZIP="$2"; shift 2 ;;
        -f|--firmware-dir) FW_DIR="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -a|--android-version) ANDROID_VER="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [ "$ANDROID_VER" != "14" ] && [ "$ANDROID_VER" != "15" ]; then
    echo "Error: Android version must be 14 or 15"
    exit 1
fi

FW_PKG_NAME="firmware-oneplus-aston-a${ANDROID_VER}"
echo "======================================"
echo " OnePlus 12R Firmware Extractor"
echo " Android version: $ANDROID_VER"
echo " Output: $OUTPUT_DIR/$FW_PKG_NAME"
echo "======================================"

check_deps() {
    local missing=false
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Missing: $cmd"
            missing=true
        fi
    done
    if $missing; then
        echo "Install missing dependencies and retry."
        exit 1
    fi
}

build_pil_squasher() {
    if command -v pil-squasher &>/dev/null; then
        echo "[OK] pil-squasher found"
        return
    fi
    echo "[..] Building pil-squasher..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://github.com/linux-msm/pil-squasher --depth 1 "$tmpdir/pil-squasher"
    cd "$tmpdir/pil-squasher"
    make install
    cd "$OLDPWD"
    rm -rf "$tmpdir"
    echo "[OK] pil-squasher built"
}

create_fw_structure() {
    local base="$OUTPUT_DIR/$FW_PKG_NAME"
    mkdir -p "$base/DEBIAN"
    mkdir -p "$base/usr/lib/firmware/qca"
    mkdir -p "$base/usr/lib/firmware/ath12k/WCN7850/hw2.0"
    mkdir -p "$base/usr/lib/firmware/qcom/sm8550/aston"
    mkdir -p "$base/usr/lib/firmware/qcom/vpu"

    cat > "$base/DEBIAN/control" <<CTRL
Package: firmware-oneplus-aston-a${ANDROID_VER}
Version: 1.0
Architecture: arm64
Maintainer: Doruk <doruk@opencode>
Description: Qualcomm firmware for OnePlus 12R (Android ${ANDROID_VER})
CTRL
    echo "$base"
}

extract_from_device() {
    echo "[..] Extracting firmware from device..."
    check_deps adb

    if ! adb devices | grep -q "device$"; then
        echo "Error: No Android device connected. Connect via USB and enable ADB."
        exit 1
    fi

    local base
    base="$(create_fw_structure)"

    echo "[..] Pulling firmware from /lib/firmware..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    adb pull /lib/firmware/ "$tmpdir/fw/" 2>/dev/null || {
        echo "Error: ADB pull failed. Try running as root on device (su)."
        exit 1
    }

    cp -rf "$tmpdir/fw/qca/"* "$base/usr/lib/firmware/qca/" 2>/dev/null || true
    cp -rf "$tmpdir/fw/ath12k/"* "$base/usr/lib/firmware/ath12k/" 2>/dev/null || true
    cp -rf "$tmpdir/fw/qcom/"* "$base/usr/lib/firmware/qcom/" 2>/dev/null || true

    local fw_list=(
        a740_zap.mbn adsp_dtb.mbn adsp.mbn cdsp_dtb.mbn cdsp.mbn
        ipa_fws.mbn modem_dtb.mbn modem.mbn vpu30_4v.mbn
        astonsnd-tplg.bin regulatory.db regulatory.db.p7s
        a740_sqe.fw gmu_gen70200.bin
    )

    for f in "${fw_list[@]}"; do
        find "$tmpdir/fw/" -name "$f" -exec cp {} "$base/usr/lib/firmware/qcom/sm8550/aston/" \; 2>/dev/null || true
    done

    rm -rf "$tmpdir"
    echo "[OK] Firmware extracted from device"
    echo "$base"
}

extract_from_zip() {
    local zip_path="$1"
    if [ ! -f "$zip_path" ]; then
        echo "Error: File not found: $zip_path"
        exit 1
    fi

    check_deps python3
    if ! python3 -c "import payload_dumper" 2>/dev/null; then
        echo "[..] Installing payload_dumper..."
        pip3 install payload-dumper --break-system-packages 2>/dev/null ||
        pip3 install payload-dumper 2>/dev/null ||
        echo "Warning: payload_dumper install failed, trying manual extraction..."
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"
    echo "[..] Extracting $zip_path..."
    7z x "$zip_path" -o"$tmpdir/zip" -y >/dev/null 2>&1

    local payload="$tmpdir/zip/payload.bin"
    if [ ! -f "$payload" ]; then
        find "$tmpdir/zip" -name "payload.bin" -exec cp {} "$payload" \; 2>/dev/null || true
    fi

    if [ -f "$payload" ]; then
        echo "[..] Found payload.bin, dumping vendor_boot and vendor partitions..."
        mkdir -p "$tmpdir/images"
        python3 -c "
import payload_dumper, sys
try:
    payload_dumper.dump('$payload', out='$tmpdir/images', partitions=['vendor_boot', 'vendor'])
except:
    print('payload_dumper failed, will extract from zip directly')
" 2>/dev/null || true

        local vendor_img
        vendor_img=$(find "$tmpdir/images" -name "vendor.img" | head -1)
        if [ -f "$vendor_img" ]; then
            echo "[..] Mounting vendor.img..."
            mkdir -p "$tmpdir/vendor"
            mount -o loop,ro "$vendor_img" "$tmpdir/vendor" 2>/dev/null || {
                echo "Warning: Could not mount vendor.img, trying simg2img..."
                simg2img "$vendor_img" "$tmpdir/vendor_raw.img" 2>/dev/null && {
                    mount -o loop,ro "$tmpdir/vendor_raw.img" "$tmpdir/vendor" 2>/dev/null || true
                }
            }
        fi
    fi

    if [ -f "$tmpdir/zip/vendor.img" ]; then
        vendor_img="$tmpdir/zip/vendor.img"
        mkdir -p "$tmpdir/vendor"
        mount -o loop,ro "$vendor_img" "$tmpdir/vendor" 2>/dev/null || {
            simg2img "$vendor_img" "$tmpdir/vendor_raw.img" 2>/dev/null &&
            mount -o loop,ro "$tmpdir/vendor_raw.img" "$tmpdir/vendor" 2>/dev/null || true
        }
    fi

    local base
    base="$(create_fw_structure)"

    if [ -d "$tmpdir/vendor" ]; then
        echo "[..] Copying firmware from vendor..."
        cp -rf "$tmpdir/vendor/firmware/"* "$base/usr/lib/firmware/" 2>/dev/null || true
        cp -rf "$tmpdir/vendor/lib/firmware/"* "$base/usr/lib/firmware/" 2>/dev/null || true
        umount "$tmpdir/vendor" 2>/dev/null || true
    fi

    find "$tmpdir/zip" -name "vendor_boot.img" -exec sh -c '
        local vtmp="'"$tmpdir"'/vboot"
        mkdir -p "$vtmp"
        unmkbootimg "$1" > "$vtmp/header" 2>/dev/null || true
    ' _ {} \; 2>/dev/null || true

    rm -rf "$tmpdir"
    echo "$base"
}

use_existing_fw_dir() {
    local src="$1"
    if [ ! -d "$src" ]; then
        echo "Error: Directory not found: $src"
        exit 1
    fi

    local base
    base="$(create_fw_structure)"

    echo "[..] Copying firmware from $src..."
    for dir in qca ath12k qcom; do
        find "$src" -type d -name "$dir" -exec cp -rf "{}/" "$base/usr/lib/firmware/" \; 2>/dev/null || true
    done

    find "$src" -name "regulatory.db*" -exec cp {} "$base/usr/lib/firmware/" \; 2>/dev/null || true

    local needed_files=(
        "a740_zap.mbn" "adsp_dtb.mbn" "adsp.mbn" "cdsp_dtb.mbn" "cdsp.mbn"
        "ipa_fws.mbn" "modem_dtb.mbn" "modem.mbn" "vpu30_4v.mbn"
        "astonsnd-tplg.bin" "a740_sqe.fw" "gmu_gen70200.bin"
        "amss.bin" "board-2.bin" "m3.bin" "hmtbtfw20.tlv" "hmtnv20.bin"
    )

    for f in "${needed_files[@]}"; do
        find "$src" -name "$f" -exec cp {} "$base/usr/lib/firmware/qcom/sm8550/aston/" \; 2>/dev/null || true
    done

    echo "$base"
}

squash_firmware() {
    local base="$1"
    local fw_dir="$base/usr/lib/firmware/qcom/sm8550/aston"

    build_pil_squasher

    echo "[..] Squashing ADSP firmware..."
    local adsp_mdt
    adsp_mdt=$(find "$fw_dir" -name "adsp.mdt" | head -1)
    if [ -n "$adsp_mdt" ]; then
        pil-squasher "$fw_dir/adsp.mbn" "$adsp_mdt"
        rm -f "$fw_dir/adsp.mdt" "$fw_dir/adsp.b"*
    fi

    echo "[..] Squashing modem firmware..."
    if [ -f "$fw_dir/modem.b23_1" ] && [ -f "$fw_dir/modem.b23_2" ]; then
        cat "$fw_dir/modem.b23_1" "$fw_dir/modem.b23_2" > "$fw_dir/modem.b23"
        rm -f "$fw_dir/modem.b23_1" "$fw_dir/modem.b23_2"
    fi
    if [ -f "$fw_dir/modem.b24_1" ] && [ -f "$fw_dir/modem.b24_2" ]; then
        cat "$fw_dir/modem.b24_1" "$fw_dir/modem.b24_2" > "$fw_dir/modem.b24"
        rm -f "$fw_dir/modem.b24_1" "$fw_dir/modem.b24_2"
    fi

    local modem_mdt
    modem_mdt=$(find "$fw_dir" -name "modem.mdt" | head -1)
    if [ -n "$modem_mdt" ]; then
        pil-squasher "$fw_dir/modem.mbn" "$modem_mdt"
        rm -f "$fw_dir/modem.mdt" "$fw_dir/modem.b"*
    fi

    echo "[OK] Firmware squashed"
}

build_deb() {
    local base="$1"
    local pkg_name
    pkg_name=$(basename "$base")

    echo "[..] Building $pkg_name.deb..."
    cd "$OUTPUT_DIR"
    dpkg-deb --build --root-owner-group "$pkg_name"
    echo "[OK] Built $OUTPUT_DIR/$pkg_name.deb"
}

main() {
    local base=""

    if [ "$EXTRACT_DEVICE" = true ]; then
        base="$(extract_from_device)"
    elif [ -n "$FW_ZIP" ]; then
        base="$(extract_from_zip "$FW_ZIP")"
    elif [ -n "$FW_DIR" ]; then
        base="$(use_existing_fw_dir "$FW_DIR")"
    else
        echo "Error: Provide --device, --zip, or --firmware-dir"
        usage
    fi

    squash_firmware "$base"
    build_deb "$base"

    echo ""
    echo "======================================"
    echo " Firmware package ready!"
    echo " Package: $OUTPUT_DIR/${FW_PKG_NAME}.deb"
    echo " Directory: $base"
    echo "======================================"
    echo ""
    echo "To install on device:"
    echo "  sudo dpkg -i ${FW_PKG_NAME}.deb"
    echo ""
    echo "Or use with aston-rootfs_package.sh to bundle into rootfs."
}

main
