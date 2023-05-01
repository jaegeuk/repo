#!/bin/bash

_cp()
{
# scp -P $1 -r SETUP/ jaegeuk@127.0.0.1:~/
  scp -P $1 authorized_keys jaegeuk@127.0.0.1:~/
}

case $1 in
file) _cp 9222;;
dir) _cp 9223;;
f2fs) _cp 9224;;
5.10) _cp 9225;;
5.15) _cp 9226;;
6.1) _cp 9227;;
esac
