#!/bin/bash

SRC=$1
NUM=$2

_exit()
{
	echo ""
	echo "Usage: ./patch.sh [f2fs/dev | stable-v3.4] [10]"
	exit
}

if [ -z "$SRC" ] || [ -z "$NUM" ]; then
	_exit
fi

_show_current()
{
	CUR=`git branch --contains HEAD | awk '{print $2}'`
	echo " == 8 patches from current $CUR =="
	git log --oneline -8 $CUR || _exit
}

_show_src()
{
	echo " == $NUM patches from remote $SRC =="
	cat fs/crypto >/dev/null 2>&1
	if [ "$?" -eq 0 ]; then
		git log --oneline -"$NUM" $SRC fs/f2fs fs/crypto || _exit
		git log --oneline -"$NUM" $SRC --reverse fs/f2fs fs/crypto > /tmp/src || _exit
	else
		git log --oneline -"$NUM" $SRC fs/f2fs fs/crypto || _exit
		git log --oneline -"$NUM" $SRC --reverse fs/f2fs fs/crypto > /tmp/src || _exit
	fi
}

_show_src
echo ""
_show_current
echo ""

old_IFS=$IFS
IFS=$'\n'
for line in $(cat /tmp/src)
do
	hash=`echo $line | awk '{print $1}'`
	echo -n "Cherry-pick: $line? [y] "
	read ans
	
	if [ "$ans" == "y" ]; then
		git cherry-pick $hash
	fi
done
IFS=$old_IFS
