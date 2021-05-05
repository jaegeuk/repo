#!/bin/bash

case $1 in
4.9|4.14|4.19|5.4|5.10|f2fs|file|dir|whole)
	pid=`ps -aux | grep "sudo kvm" | grep $1.qcow | awk '{print $2}'`
	echo "kill: $1, $pid"
	sudo kill $pid
	;;
all)
	./kill.sh 4.14
	./kill.sh 4.19
	./kill.sh 5.4
	./kill.sh 5.10
	./kill.sh f2fs
	./kill.sh file
	./kill.sh dir
	./kill.sh whole
	;;
esac
