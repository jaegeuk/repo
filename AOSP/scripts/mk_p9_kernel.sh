#!/bin/bash

# git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9

export PATH=/opt/aarch64-linux-android-4.9/bin:$PATH
export CROSS_COMPILE=/opt/aarch64-linux-android-4.9/bin/aarch64-linux-android-

mkdir out

make ARCH=arm64 O=./out mrproper
make ARCH=arm64 O=./out p9plus_extracted_defconfig
makr ARCH=arm64 O=./out -j8
