#!/bin/bash

rm -rf out/target/product/angler/*.img

# Use 7GB RAM for Jack Server -1GB from 8GB
export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx7000m"
# Killing...
out/host/linux-x86/bin/jack-admin kill-server
# Starting...
out/host/linux-x86/bin/jack-admin start-server

export TARGET_PREBUILT_KERNEL=kernel/arch/arm64/boot/Image.gz-dtb

source build/envsetup.sh
lunch aosp_angler-userdebug

make clobber
make -j 32
