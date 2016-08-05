#!/bin/bash

OUT=out/target/product/angler/
VER=angler-mtc19x
TAR=$VER-f2fs.tar
EMAIL=jaegeuk.kim@huawei.com
CUR=$PWD

_download()
{
	rm -rf $VER 2>/dev/null
	mkdir $VER 2>/dev/null
	rsync -r --delete-excluded --delete gateway:/root/aosp/$OUT/boot.img $VER/
	rsync -r --delete-excluded --delete gateway:/root/aosp/$OUT/recovery.img $VER/
	rsync -r --delete-excluded --delete gateway:/root/aosp/$OUT/system/bin/fsck.f2fs $VER/
	rsync -r --delete-excluded --delete gateway:/root/aosp/$OUT/system/lib/libsqlite.so $VER/
	mv $VER/libsqlite.so $VER/system_lib_libsqlite.so
	rsync -r --delete-excluded --delete gateway:/root/aosp/$OUT/system/lib64/libsqlite.so $VER/
	mv $VER/libsqlite.so $VER/system_lib64_libsqlite.so
	ssh gateway "cd /root/f2fs-stable && git log -n 4" > $VER/README
}

_flash_img()
{
	fastboot flash boot $VER/boot.img
	fastboot flash recovery $VER/recovery.img
}

_flash()
{
	adb root
	sleep 2
	adb remount

	adb push $VER/fsck.f2fs /system/bin/
	adb push $VER/system_lib_libsqlite.so /system/lib/
	adb push $VER/system_lib64_libsqlite.so /system/lib64/
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

_download
#_patch
#_download
#_flash_img
#_flash
