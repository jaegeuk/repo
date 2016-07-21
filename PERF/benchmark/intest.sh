#!/system/bin/sh

TMP=/tmp
RES=$TMP/result

rm $RES

_init()
{
	sync
	echo 3 > /proc/sys/vm/drop_caches
}

__test()
{
	rm -rf /data/tiotest*
	_init

	i=1
	while true;
	do
		cat /sys/kernel/debug/f2fs/status | grep "Utilization:" >> $RES
		df | grep "/data" >> $RES

		_init
		echo -ne "$i :" >> $RES
		nice -n -20 $TMP/tiotest -a $i -f 1024 -b $((512*1024)) -t 1 -k 1 -k 2 -k 3 -d /data/ | grep -i "Write        1024 MBs" >> $RES
		if [ $? -eq 1 ]; then
			break
		fi
		_init
		echo -ne "$i :" >> $RES
		nice -n -20 $TMP/tiotest -a $i -f 1024 -b 4096 -r 50000 -t 1 -k 0 -k 2 -k 3 -d /data/ | grep -i "Random Write  195 MBs" >> $RES
		if [ $? -eq 1 ]; then
			break
		fi
		tail -n 4 $RES
		i=$(($i + 1))
	done
}

__test
