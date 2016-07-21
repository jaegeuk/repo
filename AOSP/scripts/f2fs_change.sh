#!/bin/sh

OUT=out/target/product/angler/
VER=angler-mtc19v

CUR=$PWD

_download()
{
	scp $OUT/boot.img jaegeuk@mac:~/Work/$VER/my_boot.img
	scp $OUT/recovery.img jaegeuk@mac:~/Work/$VER/my_recovery.img
}

_flash_img()
{
	fastboot flash boot $OUT/boot.img
	fastboot flash recovery $OUT/recovery.img
}

_flash()
{
	adb root
	sleep 2
	adb remount

	adb push $OUT/system/bin/fsck.f2fs /system/bin/
	adb push $OUT/system/lib/libsqlite.so /system/lib/
	adb push $OUT/system/lib64/libsqlite.so /system/lib64/
}

_patch()
{
	cd device/huawei/angler/
	git am *.patch

	cd $CUR/external/f2fs-tools
	git am *.patch

	cd $CUR/external/sqlite
	git am *.patch

	cd $CUR/system/extras/
	git am *.patch
}

#_patch
#_download
_flash_img
#_flash
