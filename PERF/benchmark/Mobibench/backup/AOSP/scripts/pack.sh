#!/bin/bash

if [ $1 -z ]; then
	echo "No? Copy Image.gz from $1"
else
	echo "Copy Image.gz from $1"
	$1/out/arch/arm64/boot/Image.gz
	cp $1 boot.extracted/kernel
fi

~/mkbootimg_tools/mkboot boot.extracted boot.newkernel.img
