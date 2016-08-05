#!/bin/bash

RES=$1

if [ -z $1 ]; then
	echo "parse.sh [res_file] [description]"
	exit
fi
if [ -z $2 ]; then
	echo "parse.sh [res_file] [description]"
	exit
fi

cat $RES | grep "| Write" | awk '{print $10}' > $2
echo ======= >> $2
cat $RES | grep "| Random Write" | awk '{print $11}' >> $2
