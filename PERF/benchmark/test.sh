#!/bin/bash

RES=/mnt/obb/result

adb wait-for-device
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

adb wait-for-device
__stop
adb push bin/tiotest /mnt/obb/
adb push intest.sh /mnt/obb/

adb shell "echo 20 >  /sys/fs/f2fs/mmcblk0p44/min_fsync_blocks"
adb shell /mnt/obb/intest.sh

adb pull /mnt/obb/result

#adb shell "echo 6 >  /sys/fs/f2fs/mmcblk0p44/min_fsync_blocks"
#adb shell /mnt/obb/intest.sh
