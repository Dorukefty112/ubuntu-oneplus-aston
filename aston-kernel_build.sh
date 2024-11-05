cd /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston
git clone https://github.com/jiganomegsdfdf/aston-mainline.git --depth 1 linux
cd linux
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig sm8550.config
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
_kernel_version="$(make kernelrelease -s)"
sed -i "s/Version:.*/Version: ${_kernel_version}/" /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/linux-oneplus-aston/DEBIAN/control

cat /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/arch/arm64/boot/Image /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/arch/arm64/boot/dts/qcom/sm8550-oneplus-aston.dtb > /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/Image_w_dtb
gzip Image_w_dtb
chmod +x /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/mkbootimg
/home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/mkbootimg --header_version 4 --base 0x0 --kernel /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/Image_w_dtb.gz -o boot.img

make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=../linux-oneplus-aston modules_install
rm /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux/linux-oneplus-aston/lib/modules/**/build
cd /home/runner/ubuntu-oneplus-aston/ubuntu-oneplus-aston/linux
rm -rf linux

dpkg-deb --build --root-owner-group linux-oneplus-aston
dpkg-deb --build --root-owner-group firmware-oneplus-aston
