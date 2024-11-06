#!/bin/sh

if [ "$(id -u)" -ne 0 ]
then
  echo "rootfs can only be built as root"
  exit
fi

VERSION="24.10"

truncate -s 5G rootfs.img
mkfs.ext4 rootfs.img
mkdir rootdir
mount -o loop rootfs.img rootdir

wget https://cdimage.ubuntu.com/ubuntu-base/releases/$VERSION/release/ubuntu-base-$VERSION-base-arm64.tar.gz
tar xzvf ubuntu-base-$VERSION-base-arm64.tar.gz -C rootdir

mkdir -p rootdir/data/local/tmp
mount --bind /dev rootdir/dev
mount --bind /dev/pts rootdir/dev/pts
mount --bind /proc rootdir/proc
mount -t tmpfs tmpfs rootdir/data/local/tmp
mount --bind /sys rootdir/sys

echo "nameserver 1.1.1.1" | tee rootdir/etc/resolv.conf
echo "oneplus-aston" | tee rootdir/etc/hostname
echo "127.0.0.1 localhost
127.0.1.1 oneplus-aston" | tee rootdir/etc/hosts

if uname -m | grep -q aarch64
then
  echo "cancel qemu install for arm64"
else
  wget https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-aarch64-static
  install -m755 qemu-aarch64-static rootdir/

  echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register
  echo ':aarch64ld:M::\x7fELF\x02\x01\x01\x03\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register
fi


export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH
export DEBIAN_FRONTEND=noninteractive

chroot rootdir apt update
chroot rootdir apt upgrade -y
chroot rootdir apt install -y bash-completion sudo ssh nano rmtfs u-boot-tools- cloud-init- wireless-regdb- $1

echo "[Daemon]
DeviceScale=2" | tee rootdir/etc/plymouth/plymouthd.conf

echo "[org.gnome.desktop.interface]
scaling-factor=2" | tee rootdir/usr/share/glib-2.0/schemas/93_hidpi.gschema.override

chroot rootdir glib-compile-schemas /usr/share/glib-2.0/schemas

chroot rootdir systemctl enable systemd-growfs-root.service

cp $3/oneplus-aston-debs_$2/*.deb rootdir/
chroot rootdir dpkg -i /*.deb
rm rootdir/*.deb

mkdir rootdir/var/lib/gdm
touch rootdir/var/lib/gdm/run-initial-setup

chroot rootdir apt clean

if uname -m | grep -q aarch64
then
  echo "cancel qemu install for arm64"
else
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64ld
  rm rootdir/qemu-aarch64-static
  rm qemu-aarch64-static
fi

umount rootdir/sys
umount rootdir/proc
umount rootdir/dev/pts
umount rootdir/data/local/tmp
umount rootdir/dev
umount rootdir

rm -d rootdir

7zz a rootfs.7z rootfs.img
