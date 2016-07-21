#!/bin/bash

RES=./result

rm $RES

_init()
{
	adb shell sync
	adb shell "echo 3 > /proc/sys/vm/drop_caches"
}

__test()
{
	adb shell rm -rf /data/tiotest*
	_init

	i=1
	while true;
	do
		adb shell cat /sys/kernel/debug/f2fs/status | grep "Utilization:" >> $RES
		adb shell df | grep "/data" >> $RES

		echo -ne "$i :" >> $RES
		adb shell /mnt/obb/tiotest -a $i -f 1024 -b $((512*1024)) -t 1 -k 1 -k 2 -k 3 -d /data/ | grep -i "Write        1024 MBs" >> $RES
		if [ $? -eq 1 ]; then
			break
		fi
		_init
		echo -ne "$i :" >> $RES
		adb shell /mnt/obb/tiotest -a $i -f 1024 -b 4096 -r 50000 -t 1 -k 0 -k 2 -k 3 -d /data/ | grep -i "Random Write  195 MBs" >> $RES
		if [ $? -eq 1 ]; then
			break
		fi
		_init
		tail -n 4 $RES
		i=$(($i + 1))
	done
}

adb root
sleep 1
adb shell stop

adb shell "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
adb push bin/tiotest /mnt/obb/

adb shell "echo 6 >  /sys/fs/f2fs/mmcblk0p44/min_fsync_blocks"
__test

adb shell "echo 20 >  /sys/fs/f2fs/mmcblk0p44/min_fsync_blocks"
__test
