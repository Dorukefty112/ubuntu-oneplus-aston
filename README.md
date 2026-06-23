<img align="right" src="ubnt.png" width="305" alt="Ubuntu 26.04 Running On A OnePlus 12R">

# Ubuntu for OnePlus 12R / Ace 3 (aston)

> ```c
> /*
>  *  ⚠️  DISCLAIMER
>  *  ===============
>  *  
>  *  Your warranty is now void.
>  *  
>  *  I am not responsible for hard bricked devices, dead SD cards,
>  *  ww3, or you getting fired because the alarm app
>  *  failed. Please do some research if you have any concerns about
>  *  features included in this operating system  before flashing it!
>  *  YOU are choosing to make these modifications, and if
>  *  you point the finger at me for messing up your device,
>  *  I will laugh at you.
>  *  
>  *  ---
>  *  
>  *  This project is provided as-is, without any warranty.
>  *  The authors are not responsible for any damage, data loss,
>  *  or voided warranties. Use at your own risk.
>  *  
>  *  This build was produced by an AI agent (opencode/big-pickle).
>  *  Human involvement was limited to following instructions
>  *  and providing device access.
>  */
> ```

## Credits

This project is a fork of [jiganomegsdfdf/ubuntu-oneplus-aston](https://github.com/jiganomegsdfdf/ubuntu-oneplus-aston) — massive thanks to the original developer for the kernel, firmware squashing, and ALSA work.

## Prerequisites

- OnePlus 12R / Ace 3 (CPH2609, codename "aston")
- Unlocked bootloader
- TWRP recovery installed
- ADB & Fastboot on your PC
- Enough free space (~70 GB recommended for Ubuntu)

## Dualboot Setup

This guide sets up **Android on slot A** and **Ubuntu on slot B**. You switch between them with `fastboot set_active a/b`.

### 1. Repartition (WARNING: wipes Android data)

Enter TWRP and use `parted`:

```
adb push parted /tmp
adb shell
chmod +x /tmp/parted
/tmp/parted /dev/block/sda
print
rm <userdata_partition_number>
mkpart userdata f2fs 17GB 181GB
mkpart win ext4 181GB 251GB
quit
```

Format:
- Format `userdata` as f2fs in TWRP
- `mkfs.ext4 /dev/block/by-name/win`

### 2. Flash Ubuntu

From bootloader mode:

```
# Flash rootfs
fastboot flash win rootfs.img

# Disable boot verification on slot B
fastboot flash vbmeta_b vbmeta_b_disabled.img

# Flash boot image to slot B
fastboot flash boot_b boot16G_A14.img

# Boot Ubuntu
fastboot set_active b
fastboot reboot
```

### 3. Switch Between OS

```
fastboot set_active a    # Android
fastboot set_active b    # Ubuntu
fastboot reboot
```

### Troubleshooting

**Ubuntu doesn't boot from slot B**
Try with `fastboot boot boot16G_A14.img`. If that works but flash doesn't, re-flash `vbmeta_b_disabled.img`.

**Bootloop after switching slots**
Clear BCB in misc partition:
```
adb shell dd if=/dev/zero of=/dev/block/by-name/misc
```

**Ubuntu boots once then stops**
Try 2-3 power cycles. Some boot image header combinations are picky.

## Building from Source

### Firmware Extraction

Firmware blobs are not included in the repo (some exceed GitHub's 100 MB limit).

```
# Extract from device via ADB (root required)
./extract-firmware.sh --device -a 14

# Extract from stock OxygenOS ZIP
./extract-firmware.sh --zip ~/Downloads/OnePlus-12R-CPH2609.zip -a 14

# For Android 15, use -a 15
```

### Build Pipeline

```
./aston-kernel_build.sh      # kernel → boot.img, linux.deb
./aston-fw_squasher-a14.sh   # or use extract-firmware.sh instead
./aston-rootfs_build.sh      # rootfs.img
./aston-rootfs_package.sh    # install debs into rootfs
```

### Quick Setup Script

```
./setup-dualboot.sh --flash -a 14
```
