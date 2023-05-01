#!/bin/bash

case $1 in
5.10|5.15|6.1|f2fs|file|dir)
  pid=`ps -aux | grep "kvm" | grep $1.qcow | awk '{print $2}'`
  if [ "$pid" ]; then
    echo "kill: $1, $pid"
    sudo kill $pid
  fi
  ;;
all)
  ./kill.sh file
  ./kill.sh dir
  ./kill.sh 5.10
  ./kill.sh 5.15
  ./kill.sh 6.1
  ./kill.sh f2fs
  ;;
esac
