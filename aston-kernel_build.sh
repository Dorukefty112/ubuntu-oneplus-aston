git clone https://github.com/jiganomegsdfdf/aston-mainline.git --depth 1 linux
cd linux
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig sm8550.config
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
_kernel_version="$(make kernelrelease -s)"
sed -i "s/Version:.*/Version: ${_kernel_version}/" ../linux-oneplus-aston/DEBIAN/control

cat arch/arm64/boot/Image arch/arm64/boot/dts/qcom/sm8550-oneplus-aston.dtb > Image_w_dtb
gzip Image_w_dtb
mkbootimg --header_version 4 --base 0x0 --kernel ./Image_w_dtb.gz -o boot.img

make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=../linux-oneplus-aston modules_install
rm ../linux-oneplus-aston/lib/modules/**/build
cd ..
rm -rf linux

dpkg-deb --build --root-owner-group linux-oneplus-aston
dpkg-deb --build --root-owner-group firmware-oneplus-aston
