#!/bin/bash


_start_xfs()
{
  DIR=/mnt/xfstests
  kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratch.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-testlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-scratchlog.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-logwriter.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_start_fsstress()
{
  DIR=/mnt/fsstress
  kvm -m 4g -cpu host -smp 8 -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -drive file=$DIR/$1-test.qcow,if=virtio,discard=unmap -nographic -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22 > ./$1.out
}

_install_fsstress()
{
  DIR=/mnt/xfstests
  kvm -m 4g -cpu host -smp 8 -boot d -cdrom /usr/local/google/home/jaegeuk/Downloads/ubuntu-23.10-live-server-amd64.iso -drive file=$DIR/$1.qcow,if=virtio,discard=unmap -serial mon:stdio -net nic,model=virtio -net user,hostfwd=tcp::$2-:22
}

case $1 in
file) _start_fsstress $1 9222 &;;
dir) _start_fsstress $1 9223 &;;
#file) _install_fsstress $1 9222 &;;
#dir) _install_fsstress $1 9223 &;;
f2fs) _start_xfs $1 9224 &;;
5.15) _start_xfs $1 9225 &;;
6.1) _start_xfs $1 9226 &;;
6.6) _start_xfs $1 9227 &;;
all)
  ./qemu.sh file
  ./qemu.sh dir
  ./qemu.sh f2fs
  ./qemu.sh 5.15
  ./qemu.sh 6.1
  ./qemu.sh 6.6
;;
esac
