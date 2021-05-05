#!/bin/bash

DIR=/mnt/nvme

echo "qemu-img create -f qcow2 /mnt/nvme/5.10.qcow 64G"

for filename in $(ls $DIR | grep qcow)
do
	echo "======= $filename ========="
	qemu-img check -r all $DIR/$filename
done;

