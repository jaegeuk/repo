#!/bin/bash

DIR=./qemu

_start()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratch.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-testlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratchlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-logwriter.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_start_fsstress()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}


_start_g()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratch.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-testlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratchlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-logwriter.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_install()
{
	sudo kvm -m 4g -cpu host -smp 8 -boot d -cdrom ~/Downloads/ubuntu-20.10-live-server-amd64.iso -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22
}

case $1 in
4.14) _start 4.14 9223 &;;
4.19) _start 4.19 9224 &;;
5.4) _start 5.4 9225 &;;
f2fs) _start f2fs 9226 &;;
5.10) _start 5.10 9227 &;;
file) _start_fsstress file 9222 &;;
dir) _start_fsstress dir 9223 &;;
whole) _start_fsstress whole 9224 &;;
all)
	./qemu.sh 4.14
	./qemu.sh 4.19
	./qemu.sh 5.4
	./qemu.sh 5.10
	./qemu.sh f2fs
	./qemu.sh file
	./qemu.sh dir
	./qemu.sh whole
	;;
esac
