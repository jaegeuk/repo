#!/bin/bash

DIR=./qemu

_start()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_start_g()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_install()
{
	sudo kvm -m 4g -cpu host -smp 8 -boot d -cdrom ubuntu-20.04.2-live-server-amd64.iso -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}


_start_128()
{
	sudo kvm -m 128g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_start file 9222 &
_start dir 9223 &
_start whole 9224 &
