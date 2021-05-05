#!/bin/bash

rm -rf f2fs.orig

cd f2fs
git clean -dfx
cp ../kernel_config .config
rm vmlinux-gdb.py
make -j `getconf _NPROCESSORS_ONLN` deb-pkg LOCALVERSION=-custom
