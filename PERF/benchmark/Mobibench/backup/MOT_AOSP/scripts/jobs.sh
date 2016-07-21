#!/bin/sh

TARGET=/mnt/obb/
SYSTEM=/system/bin/
TOP=~/ssd1/android/

setup ()
{
	###Set time zone
	if [ `date +%z` -eq "-0600" ];then
        	$ADB_DEVICE shell setprop persist.sys.timezone "America/Chicago"
        elif [ `date +%z` -eq "+0800" ];then
        	$ADB_DEVICE shell setprop persist.sys.timezone "Asia/Shanghai"
	fi
	###Set the time stamp
	DATE=`date +"%Y%m%d.%k%M%S" | busybox sed 's/ //g'`;$ADB_DEVICE shell "date -s $DATE"

	###Clean logs
	$ADB_DEVICE shell rm -r /data/aplogd/* > /dev/null
        $ADB_DEVICE shell rm -r /data/dontpanic/* > /dev/null
        $ADB_DEVICE shell rm -r /data/tombstones/* > /dev/null
        $ADB_DEVICE shell rm -r /data/kernelpanics/* > /dev/null

	###Set USB persist
	$ADB_DEVICE shell setprop persist.service.adb.enable 1
}

__factory_debug()
{
	adb -s $DEV shell setprop persist.factory.allow_adb 1
	adb -s $DEV shell setprop persist.service.adb.enable 1
	adb -s $DEV shell sync
}

__sleep()
{
	for i in `seq 1 $1`
	do
		echo -en "\r $i / $1"
		sleep 1
	done
	echo ""
}

__wait_stable()
{
	__sleep 100
}

__paniclog_check ()
{
	__sleep 10
	adb -s $DEV shell "dmesg" >> ./job.$DEV.full_log
	adb -s $DEV shell "dmesg" | grep "f2fs" >> ./job.$DEV.log
	adb -s $DEV shell "dmesg" | grep "F2FS" >> ./job.$DEV.log
	WRONG=`adb -s $DEV shell "dmesg" | grep "f2fs" | grep "Fail"`
	if [ "$WRONG" ];then
		echo "fsck.f2fs detects inconsistency\n"
		exit
	fi

	BOOTREASON=`adb -s $DEV shell "cat /proc/bootinfo" | grep "POWERUPREASON" | awk -F 'x' '{print $2}' | sed -e "s/\r//"`
	if [ "$BOOTREASON" -eq "00004000" ];then
		echo "adb reboot\n"
	fi
	if [ "$BOOTREASON" -eq "00008000" ];then
		echo "watchdog reset\n"
		exit
	fi
	if [ "$BOOTREASON" -eq "00020000" ];then
		echo "kernel panic\n"
		exit
	fi
	echo "no panic: $BOOTREASON"
}

__cleanup()
{
	UTIL=`adb -s $DEV shell "cat /sys/kernel/debug/f2fs/status" | grep Utilization | busybox sed 's/\%//' | awk '{print $2}'`
	if [ $UTIL -gt 80 ]; then
		echo "clean up test directory $UTIL%"
		adb -s $DEV shell busybox rm -rf /data/test >/dev/null 2>/dev/null
	fi
}

__fsstress()
{
	adb -s $DEV push $TOP/bin/fsstress /data/ >/dev/null 2>&1
	(adb -s $DEV shell "/data/fsstress -f rename=3 -f mkdir=2 -f symlink=2 -f unlink=2 -f link=2 -f fsync=1 -f dread=1 -f dwrite=1 -f sync=0 -p 4 -n 200000 -l -d /data/test" >/dev/null 2>&1) &
	if [ $? -ne 0 ]; then
		echo "fsstress got wrong!"
	fi
#        (adb -s $DEV shell "monkey -p com.android.chrome --throttle 500 --pct-touch 60 --pct-syskeys 3000 30000") &
	__sleep 240
}

case "$1" in
test)
	ssh jaegeuk@test
	exit;;
vm)
	ssh kjgkr@vm
	exit;;
ubuntu)
	ssh -p 2222 kjgkr@ubuntu
	exit;;
mot)
	ssh jaegeuk@ca101lnxdroid81.am.mot-mobility.com
	exit;;
vvv)
	VERSION=quark
	FSOPT=f2fs
	cp ./android-$VERSION/output/boot.img ./imgs/boot-$VERSION-$FSOPT.img
	cp ./android-$VERSION/output/system.img ./imgs/system-$VERSION-$FSOPT.img
	adb reboot bootloader
	fastboot -w
	fastboot flash system ./imgs/system-$VERSION-$FSOPT.img
	fastboot flash boot ./imgs/boot-$VERSION-$FSOPT.img
	fastboot reboot
	exit;;
go)
	num=$2
	run=17
	;;
esac

while [ 1 ]
do

__device()
{
	echo "========================================================================="
	echo "|  1. LBVV190139 kinzie-m               - v3.10 stress test             |"
	echo "|  2. NC4L2C0050 osprey-m               - v3.10  stress test            |"
	echo "|  3. NSCA371233 surnia-l Samsung (8G)  - v3.10 power cuts (adb reboot) |"
	echo "|  4. LX0A150072 clark-m                - v3.10 power cuts (warthog)    |"
	echo "|  5. LC5Z2B0077 osprey-m perf                                          |"
	echo "===========+============================================================="
	echo "Current adb devices:"
	adb devices | sed '1d' | awk '{print $1}'
	echo "Current fastboot devices:"
	sudo fastboot devices | awk '{print $1}'

	echo -n "Which one? "
	read num
	echo ""
}

if [ "$1" != "go" ]
then
	__device
fi

case "$num" in
1)
	DEV=LBVV190139
	VERSION=kinzie-m
	FSOPT=f2fs
	TESTNUM=2
	MEMSIZE=2g
	;;
2)
	DEV=NC4L2C0050
	VERSION=osprey-m
	;;
3)
	DEV=NSCA371233
	VERSION=surnia-l
	FSOPT=f2fs_barrier
	TESTNUM=4
	;;
4)
	DEV=LX0A150072
	VERSION=clark-m
	;;
5)
	DEV=LC5Z2B0077
	VERSION=osprey-m
	;;
*)
	echo "No choice"
	exit
	;;
esac

__run ()
{
	echo "=========================================="
	echo "| 1. adb reboot bootloader               |"
	echo "| 2.     shell                           |"
	echo "| 3.     reboot                          |"
	echo "| 4. fastboot flash system.img           |"
	echo "| 5.                boot.img             |"
	echo "| 6.                all                  |"
	echo "| 7.          erase                      |"
	echo "| 8.          erase & flash boot.img     |"
	echo "| 9.          dump userdata              |" 
	echo "| 10. adb push perf binaries & run clean |"
	echo "| 11. adb push perf binaries & run dirty |"
	echo "| 12. adb push all the binaries          |"
	echo "| 13. download binaries from bin/        |"
	echo "| 14. salt test                          |"
	echo "| 15. fasstress + memtester              |" 
	echo "| 16. fsstress + memtester on esdfs      |" 
	echo "| 17. fastboot bootloader                |"
	echo "| 18. f2fs io trace                      |"
	echo "| 19. watch f2fs status                  |"
	echo "| 20. power loop test (adb reboot)       |"
	echo "| 21. power loop test (warthog)          |"
	echo "| 22. iozone                             |"
	echo "| 23. reset                              |"
	echo "=========================================="
	echo -n "Which one? "
	read run
}

if [ "$1" != "go" ]
then
	__run
fi

__stop()
{
	adb -s $DEV shell stop bug2go
	adb -s $DEV shell stop thermal-engine

	# turn off the screen
#	adb -s $DEV shell stop perfd

	adb -s $DEV shell "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
	adb -s $DEV shell "echo performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor"
	adb -s $DEV shell "echo performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor"
	adb -s $DEV shell "echo performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor"

	adb -s $DEV shell "echo 0 > /sys/class/mmc_host/mmc0/clk_scaling/enable"
#	adb -s $DEV shell "echo 0 > /sys/module/msm_thermal/core_control/enabled"
	adb -s $DEV shell "echo "4:0" > /sys/module/msm_performance/parameters/max_cpus"

	adb -s $DEV shell "cat /sys/kernel/debug/mmc0/max_clock > /sys/kernel/debug/mmc0/clock"
	adb -s $DEV shell "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
	adb -s $DEV shell "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"

	#adb -s $DEV shell "echo Y > /sys/module/lpm_levels/parameters/sleep_disabled"

	#adb -s $DEV shell stop
	#adb -s $DEV shell stop sdcard
	#adb -s $DEV shell stop ril-daemon
	#adb -s $DEV shell stop media
	#adb -s $DEV shell stop drm
	#adb -s $DEV shell stop keystore
	#adb -s $DEV shell stop tf_daemon
	#adb -s $DEV shell stop bluetoothd
	#adb -s $DEV shell stop hciattach
	#adb -s $DEV shell stop p2p_supplicant
	#adb -s $DEV shell stop wpa_supplicant
	#adb -s $DEV shell stop mobicore
	#adb -s $DEV shell umount /sdcard >/dev/null 2>&1
	#adb -s $DEV shell umount /mnt/sdcard >/dev/null 2>&1
	#adb -s $DEV shell umount /mnt/shell/sdcard0 >/dev/null 2>&1
	#adb -s $DEV shell umount /mnt/shell/emulated >/dev/null 2>&1
	#adb -s $DEV shell umount /cache >/dev/null 2>&1

	adb -s $DEV shell sync
	adb -s $DEV shell sync

	adb -s $DEV shell "echo 3 > /proc/sys/vm/drop_caches"
}

__push_bin()
{
#	adb -s $DEV install $TOP/MobiBench-debug.apk
	adb -s $DEV install $TOP/SDPlay.apk
#	adb -s $DEV remount /system
	adb -s $DEV push $TOP/bin/run.sh $TARGET
	adb -s $DEV push $TOP/bin/bench.sh $TARGET
	adb -s $DEV push $TOP/bin/iozone $TARGET
	adb -s $DEV push $TOP/bin/fsck.f2fs $TARGET
	adb -s $DEV push $TOP/bin/mkfs.f2fs $TARGET
	adb -s $DEV push $TOP/bin/fsstress $TARGET
	adb -s $DEV push $TOP/bin/mot.iozone $TARGET
	adb -s $DEV push $TOP/bin/mot.mmc $TARGET
#	adb -s $DEV push $TOP/bin/mot.mobibench $TARGET
#	adb -s $DEV push $TOP/bin/mobibench_shell $TARGET
	adb -s $DEV push $TOP/tracepoint.sh $TARGET
}

__reset()
{
	__stop
	adb -s $DEV shell busybox rm -rf /data/data/com.elena.sdplay/files*
	adb -s $DEV shell sync
	adb -s $DEV shell sync
	adb -s $DEV shell "echo 3 > /proc/sys/vm/drop_caches"
}

__wait_adb()
{
	adb -s $DEV wait-for-device >/dev/null 2>/dev/null
	adb -s $DEV root >/dev/null 2>/dev/null
}

case "$run" in
1)
	__wait_adb
	adb -s $DEV reboot bootloader
	;;
2)
	__wait_adb
	adb -s $DEV shell
	;;
3)
	__wait_adb
	adb -s $DEV reboot
	;;
4)
	sudo fastboot -s $DEV flash system $TOP/android-$VERSION/output/system.img
	;;
5)
	sudo fastboot -s $DEV flash boot $TOP/android-$VERSION/output/boot.img
	sudo fastboot -s $DEV reboot
	;;
6)
	cd $TOP/android-$VERSION/output
	sudo fastboot -s $DEV -w
	sudo ./flashall.sh $DEV
	;;
7)
	sudo fastboot -s $DEV -w
	sudo fastboot -s $DEV reboot
	;;
8)
	sudo fastboot -s $DEV flash boot $TOP/android-$VERSION/output/boot.img
	sudo fastboot -s $DEV -w
	sudo fastboot -s $DEV reboot
	;;
9)
	sudo fastboot -s $DEV oem partition dump userdata
	;;
10)
	__wait_adb
	__stop
	__push_bin
	adb -s $DEV shell mount
	adb -s $DEV shell mot.mmc extcsd read /dev/block/mmcblk0
	sleep 30
	adb -s $DEV shell "/mnt/obb/run.sh 9"
	;;
11)
	__wait_adb
	__push_bin
	adb -s $DEV shell mount
	adb -s $DEV shell mot.mmc extcsd read /dev/block/mmcblk0
	sleep 10
	adb -s $DEV shell "/mnt/obb/run.sh $TESTNUM"
	;;
12)
	__wait_adb
	adb -s $DEV shell touch /pds/public/atvc/atvc.db
	__push_bin
	__stop
	__reset
	;;
13)
#	scp jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/benchmark/Mobibench/MobiBench/bin/MobiBench-debug.apk ./
#	scp jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/f2fs-tools/scripts/tracepoint.sh ./
	scp jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/android-quark/output/system/bin/mot.mobibench ./bin/
	scp jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/android-quark/output/system/bin/mot.iozone ./bin/
	scp jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/android-quark/output/system/bin/mot.mmc ./bin/
	scp -r jaegeuk@ca101lnxdroid81.am.mot-mobility.com:~/repo/benchmark/bin/mobibench_shell ./bin/
	;;
14)
	__wait_adb
	cd salttest-v04.21-kk
	./runsalt.sh $VERSION $DEV ./
	;;
15)
	__wait_adb
	adb -s $DEV shell busybox rm -rf /data/test

	adb -s $DEV push $TOP/memtester /data/
	adb -s $DEV push $TOP/bin/fsstress /data/
#	(adb -s $DEV shell "/data/memtester $MEMSIZE -1") &

	adb -s $DEV shell "/data/fsstress -f rename=3 -f mkdir=2 -f symlink=2 -f unlink=2 -f link=2 -f fsync=1 -f dread=1 -f dwrite=1 -f sync=0 -p 10 -n 300000 -v -l -d /data/test"
	#adb -s $DEV shell "/data/fsstress -f fsync=2 -f dread=1 -f dwrite=3 -f sync=0 -p 30 -n 50000 -l -v -d /data/test"
	#adb -s $DEV shell /data/fsstress -v -f sync=1 -p 10 -n 50000 -l 0 -d /data/test
	;;
16)
	__wait_adb
	adb -s $DEV push $TOP/memtester /data/
	adb -s $DEV push $TOP/bin/fsstress /data/
	adb -s $DEV shell /data/memtester $MEMSIZE -1 &
	adb -s $DEV shell "/data/fsstress -f rename=1 -f mkdir=1 -f fsync=1 -f dread=1 -f dwrite=2 -f sync=0 -p 4 -n 100000 -v -l -d /mnt/sheel/emulated"
	#adb -s $DEV shell "/data/fsstress -f fsync=2 -f dread=1 -f dwrite=3 -f sync=0 -p 30 -n 50000 -l -v -d /mnt/shell/emulated"
	;;
17)
	sudo fastboot -s $DEV flash aboot EMMCBOOT.MBN
	sudo fastboot -s $DEV reboot-bootloader
	;;
18)
	__wait_adb
	sudo adb -s $DEV shell "echo 1 > /sys/kernel/debug/tracing/trace_on"
	sudo adb -s $DEV shell "cat /sys/kernel/debug/tracing/trace_pipe"
	;;
19)
	__wait_adb
	watch -n 1 sudo adb -s $DEV shell "cat /sys/kernel/debug/f2fs/status"
	;;
20)
	while [ 1 ]
	do
		__wait_adb
		__paniclog_check
		__wait_stable
		__fsstress
		sudo adb -s $DEV "echo c > /proc/sysrq-trigger"
	done
	;;
21)
	rm ./job.$DEV.log
	rm ./job.$DEV.full_log
	touch ./job.$DEV.log
	touch ./job.$DEV.full_log

	runs=0

	__wait_adb
	__factory_debug

	while [ 1 ]
	do
		runs=$(($runs + 1))
		echo LOOP: $runs
		echo "***********************************" >> ./job.$DEV.full_log
		echo "LOOP: $runs" >> ./job.$DEV.full_log
		echo "***********************************" >> ./job.$DEV.log
		echo "LOOP: $runs" >> ./job.$DEV.log
		__wait_adb
		__paniclog_check
		__cleanup
		__wait_stable
		__fsstress
		warthog_off LWAS220171
		__sleep 5
		warthog_on LWAS220171
	done
	;;
22)
	__wait_adb
	adb -s $DEV shell "/data/run.sh 9"
#	adb -s $DEV push $TOP/tracepoint.sh $TARGET
#	adb -s $DEV shell dmesg | grep F2FS
#	adb -s $DEV shell logcat | grep dalvik
#	(adb -s $DEV shell $TARGET/tracepoint.sh) &
	;;
23)
	__reset
	__factory_debug
	;;
*)
	echo "No choice"
	;;
esac

done
