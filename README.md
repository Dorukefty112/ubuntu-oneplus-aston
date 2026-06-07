<img align="right" src="ubnt.png" width="305" alt="Ubuntu 26.04 Running On A OnePlus 12R">

# Ubuntu for OnePlus 12R / Ace 3 (aston)

> ⚠️ **DISCLAIMER**: This project is provided as-is, without any warranty. The authors are not responsible for any damage, data loss, or voided warranties. Use at your own risk.
> 
> This build was produced by an **AI agent** (opencode/big-pickle). Human involvement was limited to following instructions and providing device access.

## Credits

This project is a fork of [jiganomegsdfdf/ubuntu-oneplus-aston](https://github.com/jiganomegsdfdf/ubuntu-oneplus-aston) — massive thanks to the original developer for the kernel, firmware squashing, and ALSA work.

## Status

### Working
- Ubuntu 26.04 (Stonking) with GNOME Desktop
- Kernel 6.14.0-sm8550 (mainline)
- WiFi (ath12k)
- SSH over WiFi
- GPU acceleration (A740)
- Touchscreen
- HiDPI scaling
- USB networking (RNDIS)
- ALSA sound
- A/B slot dualboot (manual switching via fastboot)
- Bluetooth (basic)

### Not Working / Untested
- Modem / SMS / Calls (WIP — no fix yet)
- Automatic dualboot switching
- Suspend / Resume
- Camera
- GPS
- NFC
- Fingerprint sensor

## Prerequisites

- OnePlus 12R / Ace 3 (CPH2609, codename "aston")
- Unlocked bootloader
- TWRP recovery installed (can be on `recovery` or patched `init_boot`)
- ADB & Fastboot on your PC
- Enough free space (~70 GB recommended for Ubuntu)

## Partition Layout (Dualboot)

| Partition | Size | Filesystem | Content |
|-----------|------|------------|---------|
| `super` | 16.6 GB | - | Android system |
| `userdata` | ~164 GB | f2fs | Android data |
| `win` | ~70 GB | ext4 | Ubuntu rootfs |

- **Slot A**: Android (untouched system partitions)
- **Slot B**: Ubuntu (separate `boot_b` + `win` partition)

Switch between OS with:
```
fastboot set_active a  # Android
fastboot set_active b  # Ubuntu
fastboot reboot
```

## Installation

### 1. Repartition (WARNING: wipes Android data)
Use `parted` in TWRP:
```
adb push parted /tmp
adb shell
chmod +x /tmp/parted
/tmp/parted /dev/block/sda
print               # note userdata start/end
rm <userdata_num>   # delete userdata
mkpart userdata f2fs <start> <new_end>
mkpart win ext4 <new_end> <original_end>
quit
```
Then format:
- Format userdata as f2fs in TWRP
- `mkfs.ext4 /dev/block/by-name/win`

### 2. Flash rootfs
```
adb push rootfs.img /tmp/   # needs ~7 GB free in /tmp
adb shell dd if=/tmp/rootfs.img of=/dev/block/by-name/win
```

### 3. Flash boot image
```
adb shell dd if=/tmp/boot.img of=/dev/block/by-name/boot_b
```

### 4. Boot Ubuntu
```
fastboot set_active b
fastboot reboot
```

## Switching Back to Android
```
fastboot set_active a
fastboot reboot
```
First boot after wipe will show setup wizard.

## Building from Source
Run the scripts in order:
```
./aston-kernel_build.sh      # builds kernel, boot.img, linux .deb
./aston-fw_squasher-a14.sh   # builds firmware .deb
./aston-rootfs_build.sh      # builds rootfs.img
./aston-rootfs_package.sh    # installs .deb packages into rootfs
```
  


