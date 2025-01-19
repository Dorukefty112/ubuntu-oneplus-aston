git clone https://github.com/linux-msm/pil-squasher --depth 1
cd pil-squasher
make install


/usr/local/bin/pil-squasher $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/adsp.mbn $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/adsp.mdt
rm -rf $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/adsp.mdt $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/adsp.b*


cat $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b23_1 $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b23_2 > $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b23
cat $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b24_1 $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b24_2 > $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b24
/usr/local/bin/pil-squasher $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.mbn $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.mdt
rm -rf $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.mdt $1/firmware-oneplus-aston/usr/lib/firmware/qcom/sm8550/aston/modem.b*
