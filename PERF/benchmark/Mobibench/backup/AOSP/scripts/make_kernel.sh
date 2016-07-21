#!/bin/sh

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export PATH=$(pwd)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin:$PATH

cd kernel
make angler_defconfig
make -j 16

echo "Linux version 3.10.73-g0c9f594 (android-build@wpiv12.hot.corp.google.com)
    (gcc version 4.9.x-google 20140827 (prerelease) (GCC) ) #1 SMP PREEMPT"
