#!/system/bin/sh

DIR=/mnt/obb
TEST=/data/
TESTFILE=testfile
SIZE=$((1024*1024))

rm $TEST/*.db0
rm $TEST/*.wal
rm $TESTFILE

__stat()
{
	df
	cat /sys/kernel/debug/f2fs/status
}

__init()
{
	sync
	echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	echo 3 > /proc/sys/vm/drop_caches
	echo 0 > /sys/block/mmcblk0/queue/read_ahead_kb
#	echo row > /sys/block/mmcblk0/queue/scheduler
}

__seq_write()
{
	__init
	$DIR/iozone $2 -e -w -s $SIZE -r 4 -f $TEST/$1 -i 0 -+n
}

__seq_read()
{
	__init
	$DIR/iozone $2 -e -w -s $SIZE -r 4 -f $TEST/$1 -i 1 -+n
}

__rand_rw()
{
	__init
	$DIR/iozone $2 -+a 3 -e -w -s $SIZE -r 4 -f $TEST/$1 -i 2 -+n
}

__run_iozone()
{
	__seq_write $TESTFILE-$1 ""
	__seq_read $TESTFILE-$1 ""
	__rand_rw $TESTFILE-$1 ""
}

__make_dirty()
{
	num=$((USER_SIZE*2/3))
	i=1
	j=1
	echo -ne "Filling $i / $num GBs, random writes $j'th file"
	while [ $i -lt $num ]
	do
		j=1
		echo -ne "\rFilling $i GBs, random writes $j'th file"
		__seq_write "dirty$i" #1> /dev/null

		while [ $j -le $i ]
		do
			__rand_rw "dirty$j" "-+b" #1> /dev/null
			echo -ne "\rFilling $i GBs, random writes $j'th file"
			j=$(($j + 1))
		done
		i=$(($i + 1))
	done
	echo ""

	i=1
	echo -ne "Random writes $i / $num file"
	while [ $i -lt $num ]
	do
		echo -ne "\rRandom writes $i / $num file"
		__rand_rw "dirty$i" "-+b" #1> /dev/null
		i=$(($i + 1))
	done
	echo ""

}

case "$2" in
quark)
	USER_SIZE=21		# GB for quark Sandisk 29.820 MB
	;;
titan)
	USER_SIZE=11		# GB for titan Samsung 14.910 MB
	;;
*)
	echo "./run.sh [iozone|mobibench] [quark|titan]"
	exit
	;;
esac

case "$1" in
iozone)
	# clean state
	__stat
	__run_iozone clean

	# dirty state
	__make_dirty
	__stat
	__run_iozone dirty
	__stat
	;;

mobibench)
	$DIR/mobibench -d 0 -n 2000 -j 2 -s 2 -p $TEST
	;;
*)
	echo "./run.sh [iozone|mobibench] [quark|titan]"
	exit
	;;
esac
