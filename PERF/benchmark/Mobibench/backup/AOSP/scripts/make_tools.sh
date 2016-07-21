#!/bin/bash

source build/envsetup.sh
lunch aosp_angler-userdebug
make fastboot adb

echo "=== check and do ===="
echo "cp out/host/linux-x86/bin/adb /usr/bin/"
echo "cp out/host/linux-x86/bin/fastboot /usr/bin/"
