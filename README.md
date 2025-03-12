<img align="right" src="ubnt.png" width="305" alt="Ubuntu 24.10 Running On A OnePlus Ace 3">

# Ubuntu for OnePlus 12R/Ace 3
This repo contians **Base Guide for installation/upgrading** and **Scripts for automatic building of Ubuntu RootFS, Mainline Kernel, Firmware package, ALSA configs** for OnePlus 12R/Ace 3

# Where do i get needed files?
Just go to the "Actions" tab, open most recent build and download files named **rootfs_(Desktop Environment)_(Kernel version)** and **boot-oneplus-aston_(Kernel version).img**
<br>For upgrading - instead, download all files available, **except for rootfs**

## Upgrading steps (From running Ubuntu)
- Unpack all .zip you downloaded in one folder
- Open terminal and go to place where you unpacked all .zip's
- Run "sudo dpkg -i *-oneplus-aston.deb"
- (If using flashing instead of **fastboot boot**) You can flash new boot image, using "dd if="**path to boot.img**" of=/dev/disk/by-partlabel/boot_**('a' or 'b')**"
- Reboot using new image

### Partitioning steps using "parted", where text inside () is command to execute
⚠️**New partition should be at least 5GB in size for rootfs.img to fit in**
<br>⚠️**You will lose all your android data**
 - Download parted executable from "Releases"
 - Reboot to TWRP recovery and push downloaded file to /tmp <br>(**adb push parted /tmp**)
 - Access phone shell <br>(**adb shell**)
 - Grant execute permission and open parted for further steps<br>(**chmod +x /tmp/parted && /tmp/parted /dev/block/sda**)
 - Look at partitions and remember "Number", "Start" "End" for "userdata" partition <br>(**print**)
 - Remove "userdata" partition <br>(**rm "Number"**)
 - Create new "userdata" partition <br>(**mkpart userdata f2fs "Start" "*End - size that you want to allocate for Ubuntu install*"**)
 - Create new "win" partition <br>(**mkpart win ntfs "*End - size that you want to allocate for Ubuntu install*" "End"**)
 - Reboot back to recovery
 - Format new "userdata" using TWRP format data function
 - Format new "win" partition <br>(**mkfs.ext4 /dev/block/by-name/win**)
  
## Install steps
- You should have custom partitions, follow "Partitioning steps..." upper
- Unpack .zip files you downloaded
- Unpack extracted rootfs.7z
- rootfs.img must be flashed to the partition named "win"
<br>⚠️**USE "dd if="path to rootfs.img" of=/dev/block/by-name/win"
<br>  FLASHING USING FASTBOOT RESULTS IN BROKEN UBUNTU FILESYSTEM**
- Flash (or **fastboot boot**) boot.img that you got from boot archive
  


