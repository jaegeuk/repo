#!/bin/sh

OUT=out/target/product/angler/
VER=angler-nrd90u

CUR=$PWD

_download()
{
	scp $OUT/boot.img jaegeuk@mac:~/Work/$VER/F2FS_boot.img
	scp $OUT/recovery.img jaegeuk@mac:~/Work/$VER/F2FS_recovery.img
	scp $OUT/system/bin/fsck.f2fs jaegeuk@mac:~/Work/$VER/
	scp $OUT/system/lib/libsqlite.so jaegeuk@mac:~/Work/$VER/system_lib_libsqlite.so
	scp $OUT/system/lib64/libsqlite.so jaegeuk@mac:~/Work/$VER/system_lib64_libsqlite.so
}

_flash_img()
{
	fastboot flash boot $OUT/boot.img
	fastboot flash recovery $OUT/recovery.img
	#fastboot flash recovery twrp-3.0.2-2-angler.img
#	fastboot flash system $OUT/system.img
#	fastboot flash cache $OUT/cache.img
#	fastboot flash userdata $OUT/userdata.img
}

_flash()
{
	adb root
	sleep 2
	adb remount

	adb push $OUT/system/bin/fsck.f2fs /system/bin/
	adb push $OUT/system/lib/libsqlite.so /system/lib/
	adb push $OUT/system/lib64/libsqlite.so /system/lib64/

	echo "mount -t ext4 /../vendor /tmp; sync /tmp/build.prop's fingerprint with /system/build.prop"
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
