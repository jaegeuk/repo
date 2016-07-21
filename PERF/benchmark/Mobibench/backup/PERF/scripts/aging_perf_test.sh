#!/bin/bash

TESTDIR=/mnt/test/
DEV=sdb1
VER=f2fs

_reload_f2fs()
{
	umount /mnt/*
	rmmod f2fs
	insmod ~/$VER/fs/f2fs/f2fs.ko
	mkfs.f2fs /dev/$DEV
}

_fs_opts()
{
	echo 100 > /sys/fs/f2fs/$DEV/gc_max_sleep_time
	echo 100 > /sys/fs/f2fs/$DEV/gc_min_sleep_time
	echo 10 > /sys/fs/f2fs/$DEV/gc_idle
	echo 10000 > /sys/fs/f2fs/$DEV/gc_no_gc_sleep_time
}

_mount()
{
	#mount -t f2fs /dev/$DEV -o no_heap,background_gc=off,active_logs=2,discard $TESTDIR
	#mount -t f2fs /dev/$DEV -o background_gc=sync,active_logs=6,discard $TESTDIR
	mount -t f2fs /dev/$DEV -o background_gc=sync,active_logs=6,discard $TESTDIR
#	mount -t f2fs /dev/$DEV -o background_gc=off,active_logs=6,discard $TESTDIR
}

_perf()
{
	sync
	echo 3 > /proc/sys/vm/drop_caches
	dd if=/dev/zero of=$TESTDIR/testfile1 bs=1M count=512 conv=fsync 2>> res
}

init()
{
	echo "START INIT" >> res
	_perf
	i=0
	while true
	do
		dd if=/dev/zero of=$TESTDIR/$i bs=4k count=4 >/dev/null 2>/dev/null
		if [ "$?" -ne 0 ]
		then
			break
		fi
		i=$(($i+1))
	done
	sync
}

delete()
{
	echo "START DELETE" >> res
	i=0
	while true
	do
		j=$(($i*2 + 1))
		rm $TESTDIR/$j >/dev/null 2>/dev/null

		if [ "$?" -ne 0 ]
		then
			break
		fi
		i=$(($i+1))
	done
	sync
}

measure()
{
	echo "START MEASURE" >> res
	_perf
	_perf
	_perf
	_perf
}

rm res
touch res

echo "EXT4_time" >> res
umount /mnt/*
mkfs.ext4 /dev/$DEV
mount -t ext4 /dev/$DEV -o discard $TESTDIR
init
delete
measure

echo "F2FS_base" >> res
_reload_f2fs
_mount
init
delete
cat /sys/kernel/debug/f2fs/status >> res
measure
cat /sys/kernel/debug/f2fs/status >> res

echo "F2FS_time" >> res
_reload_f2fs
_mount
init
delete
cat /sys/kernel/debug/f2fs/status >> res
_fs_opts
sleep 600
cat /sys/kernel/debug/f2fs/status >> res
measure
