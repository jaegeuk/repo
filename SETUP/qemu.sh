#!/bin/bash

DIR=/mnt/nvme

_start()
{
	sudo kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio -drive file=$DIR/$1-test.qcow,if=virtio -drive file=$DIR/$1-logwriter.qcow,if=virtio -drive file=$scratch.qow,if=virtio -drive file=$DIR/$1-scratchlog.qcow,if=virtio -drive file=$DIR/$1-testlog.qcow,if=virtio -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_start 5.15 9222 &
_start dir 9223 &
_start whole 9224 &
