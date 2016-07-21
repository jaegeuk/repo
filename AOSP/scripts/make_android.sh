#!/bin/bash

export TARGET_PREBUILT_KERNEL=kernel/arch/arm64/boot/Image.gz-dtb

source build/envsetup.sh
lunch aosp_angler-userdebug
make -j 32
