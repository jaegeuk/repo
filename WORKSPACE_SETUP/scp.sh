#!/bin/bash

_cp()
{
	scp -P $1 -r SETUP/ jaegeuk@127.0.0.1:~/
}

case $1 in
4.9) _cp 9222;;
4.14) _cp 9223;;
4.19) _cp 9224;;
5.4) _cp 9225;;
5.10) _cp 9227;;
5.15) _cp 9228;;
f2fs) _cp 9226;;
file) _cp 9222;;
dir) _cp 9223;;
whole) _cp 9224;;
esac
