apt-get install gcc-arm-linux-gnueabi

./build.sh all

./build.sh fsstress

=======
tiotest
=======

1. flash boot/recovery image

2. enter recovery mode

3. mkfs.f2fs /dev/block/...

# ./test.sh
