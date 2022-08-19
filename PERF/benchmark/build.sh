#!/bin/sh

#export TOOL_PREFIX=/opt/gcc-arm-none-eabi-4_9-2015q3/bin/arm-none-eabi
export TOOL_PREFIX=arm-linux-gnueabi
export CXX=$TOOL_PREFIX-g++
export AR=$TOOL_PREFIX-ar
export RANLIB=$TOOL_PREFIX-ranlib
export CC=$TOOL_PREFIX-gcc
export LD=$TOOL_PREFIX-ld
export KERNEL=/root/aosp/kernel
export KERNEL_HEADERS=$KERNEL/include

#export CCFLAGS="-static -I/opt/android-ndk-r10e/platforms/android-21/arch-arm/usr/include/" # -I$KERNEL_HEADERS"
export CCFLAGS="-static" # -I$KERNEL_HEADERS"
#export CCFLAGS="-march=armv7-a -mtune=cortex-a8 -mfpu=vfp"
#export ARM_TARGET_LIB=/opt/repo/arm-2009q1/arm-none-linux-gnueabi/libc
export ARM_TARGET_LIB=/opt/gcc-arm-none-eabi-4_9-2015q3/libc

ROOT=$PWD

case "$1" in
iozone)
	cd iozone3_493
	make linux-arm && cp iozone $ROOT/bin/
	;;
mmc)
#	cd $KERNEL
#	make headers_install INSTALL_HDR_PATH=$KERNEL_HEADERS
	cd $ROOT/mmc-utils
	make && cp mmc $ROOT/bin/
	;;
fs_mark)
	cd fs_mark-3.3
	make && cp fs_mark $ROOT/bin/
	;;
postmark)
	cd postmark
	make && cp postmark $ROOT/bin/
	;;
tiotest)
	cd tiobench-0.3.3
	make && cp tiotest $ROOT/bin/
	;;
fsstress)
#	cd $KERNEL
#	make headers_install INSTALL_HDR_PATH=$KERNEL_HEADERS
	cd $ROOT/fsstress
	make && cp fsstress $ROOT/bin/
	;;
mobibench)
	case "$2" in
	ext4)
		export TARGET_USES_ORDERED_WRITES=true
		export TARGET_USES_SEQUENTIAL_WRITES=false
		export TARGET_USES_ATOMIC_WRITES=false
		export TARGET_NEEDS_NO_DIRSYNC=false
		;;
	f2fs)
		export TARGET_USES_ORDERED_WRITES=true
		export TARGET_USES_SEQUENTIAL_WRITES=false
		export TARGET_USES_ATOMIC_WRITES=false
		export TARGET_NEEDS_NO_DIRSYNC=true
		;;
	*)
		echo "No additional sqlite build options"
		;;
	esac
	cd Mobibench/shell
	make && cp mobibench $ROOT/bin/
	;;
f2fs)
	cd f2fs-tools
 	LDFLAGS=--static ./configure #--host=$TOOL_PREFIX --target=-$TOOL_PREFIX
	make
	cp mkfs/mkfs.f2fs $ROOT/bin/
	cp mkfs/fsck.f2fs $ROOT/bin/
	;;
all)
	./build.sh clean
	./build.sh iozone
	./build.sh fs_mark
	./build.sh postmark
	./build.sh tiotest
	./build.sh mobibench
	./build.sh mmc
	;;
clean)
	cd $ROOT/iozone3_427
	make clean
	cd $ROOT/fs_mark-3.3
	make clean
	cd $ROOT/mmc-utils
	make clean
	cd $ROOT/postmark
	make clean
	cd $ROOT/tiobench-0.3.3
	make clean
	cd $ROOT/Mobibench/shell
	make clean
	cd $ROOT/bin
	rm *
	;;
*)
	echo "# build.sh [iozone | fs_mark | tiotest | postmark | mobibench]"
	;;
esac
