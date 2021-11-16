#!/bin/bash

case $1 in
4.9) ssh -p 9222 jaegeuk@127.0.0.1;;
4.14) ssh -p 9223 jaegeuk@127.0.0.1;;
4.19) ssh -p 9224 jaegeuk@127.0.0.1;;
5.4) ssh -p 9225 jaegeuk@127.0.0.1;;
5.10) ssh -p 9227 jaegeuk@127.0.0.1;;
5.15) ssh -p 9228 jaegeuk@127.0.0.1;;
f2fs) ssh -p 9226 jaegeuk@127.0.0.1;;
file) ssh -p 9222 jaegeuk@127.0.0.1;;
dir) ssh -p 9223 jaegeuk@127.0.0.1;;
whole) ssh -p 9224 jaegeuk@127.0.0.1;;
esac
