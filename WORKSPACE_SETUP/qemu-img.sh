#!/bin/bash

DIR=/mnt/nvme

echo "qemu-img create -f qcow2 /mnt/nvme/5.10.qcow 64G"
echo "qemu-img create -f qcow2 /mnt/nvme/5.10-logwriter.qcow 32G"
echo "qemu-img create -f qcow2 /mnt/nvme/5.10-scratchlog.qcow 32G"
echo "qemu-img create -f qcow2 /mnt/nvme/5.10-scratch.qcow 32G"
echo "qemu-img create -f qcow2 /mnt/nvme/5.10-test.qcow 32G"
echo "qemu-img create -f qcow2 /mnt/nvme/5.10-testlog.qcow 32G"

for filename in $(ls $DIR | grep qcow)
do
	echo "======= $filename ========="
	qemu-img check -r all $DIR/$filename
done;

