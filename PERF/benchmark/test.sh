#!/bin/bash

TMP=/tmp

RES=$TMP/result

#adb wait-for-device
adb root
sleep 1

__stop()
{
	adb shell stop

	adb shell "echo "4:0" > /sys/module/msm_performance/parameters/max_cpus"
	adb shell "echo 0 > /sys/class/mmc_host/mmc0/clk_scaling/enable"
	adb shell "echo 0 > /sys/module/msm_thermal/core_control/enabled"
	adb shell "cat /sys/kernel/debug/mmc0/max_clock > /sys/kernel/debug/mmc0/clock"

	for i in `seq 0 3`
	do
		adb shell "echo userspace > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
		adb shell "cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_setspeed"
		adb shell "cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq"
	done
	adb shell umount /mnt/runtime/default/emulated
	adb shell umount /mnt/runtime/read/emulated
	adb shell umount /mnt/runtime/write/emulated
}

__parse()
{
	grep -i "Write        1024 MBs" $1 | awk '{ print $10 }' > $1_SEQ_WRITE
	grep -i "Random Write  195 MBs" $1 | awk '{ print $11 }' > $1_RAND_WRITE
}

#adb wait-for-device
__stop
adb push bin/tiotest $TMP
adb push intest.sh $TMP

#adb shell "echo 20 >  /sys/fs/f2fs/mmcblk0p44/min_fsync_blocks"
adb shell $TMP/intest.sh

adb pull $TMP/result
FS=`adb shell mount | grep /data | awk '{ print $3 }'`
mv result "$FS"_result

__parse "$FS"_result
