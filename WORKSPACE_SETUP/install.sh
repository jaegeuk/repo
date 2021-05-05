#!/bin/bash

DIR=./qemu

_install()
{
	sudo kvm -m 4g -cpu host -smp 8 -boot d -cdrom ~/Downloads/ubuntu-20.10-live-server-amd64.iso -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22
}

case $1 in
4.14) _install 4.14 9223 &;;
4.19) _install 4.19 9224 &;;
5.4) _install 5.4 9225 &;;
f2fs) _install f2fs 9226 &;;
5.10) _install 5.10 9227 &;;
file) _install file 9222 &;;
dir) _install dir 9223 &;;
whole) _install whole 9224 &;;
esac
