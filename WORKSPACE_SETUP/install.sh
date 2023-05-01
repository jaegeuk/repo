#!/bin/bash

DIR=/mnt/nvme

_install()
{
	kvm -m 4g -cpu host -smp 8 -boot d -cdrom /usr/local/google/home/jaegeuk/Downloads/ubuntu-22.04.2-live-server-amd64.iso -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22
}

case $1 in
file) _install file 9222 &;;
dir) _install dir 9223 &;;
f2fs) _install f2fs 9224 &;;
5.10) _install 5.10 9225 &;;
5.15) _install 5.10 9226 &;;
6.1) _install 5.10 9227 &;;
esac
