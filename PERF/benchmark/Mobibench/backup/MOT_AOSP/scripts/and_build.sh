#!/bin/bash

AP=8084
BRANCH=mkkmr2-d
VERSION=quark_verizon-user
#BRANCH=mkkmr2-x
OUTPUT=out/target/quark
TARGET=KDF21.135

case "$1" in
init)
	repo init --manifest-url=ssh://gerrit.pcs.mot.com/home/repo/dev/platform/android/platform/manifest.git --repo-url=/apps/android/repo.git  -m $AP.xml --manifest-branch=$BRANCH
	repo sync build
	;;
sync)
	repo sync -j2 -c
	;;
push)
	#git push origin HEAD:refs/for/bkkmr2
	;;
target)
	repo forall -c git checkout -f $TARGET
	;;
bootimg)
	source build/envsetup.sh
	lunch $VERSION
	make -j4 bootimage
	;;
build)
	source build/envsetup.sh
	lunch $VERSION
	#mmm motorola/external/f2fs-tools/fsck
	#mmm motorola/external/f2fs-tools/mkfs
	#mmm motorola/external/f2fs-tools/benchmarks/mobibench
#	mmm motorola/external/f2fs-tools/benchmarks/iozone3_427
#	mmm motorola/external/f2fs-tools/benchmarks/mmc-utils
	#make mot.iozone
	#make mot.mobibench -j 4
#	make mot.mmc -j 4
	#make dump.f2fs -j 4
#	make mkfs.f2fs_arm -j 4
#	make fsck.f2fs -j 4
#	mmm external/sqlite/dist
#	mmm system/core/fs_mgr
#	mmm motorola/external/f2fs-tools
	make -j4
	;;
kernel)
	cd kernel
	make msm8974_defconfig ARCH=arm CROSS_COMPILE=arm-eabi-
	make -j32 ARCH=arm CROSS_COMPILE=arm-eabi-
	;;
clean)
	source build/envsetup.sh
	lunch $VERSION
	make clean
	;;
*)
	echo "# run.sh [init | sync | bootimg]"
	;;
esac

# For history
# for submitting patches
# cd motorola/externel/f2fs-tools
# git branch -a : check the current branch
#  --- bkkmr2 : goto two product lines
#  --- 8084/8974 ?
#
# git revert ####
# git remote add upstream git://git.kernel.org/pub/scm/linux/kernel/git/jaegeuk/f2fs-tools.git
# git fetch upstream
# git merge upstream/master
# 
# git push origin HEAD:refs/heads/sandbox/jaegeuk/[branch name]
# git reset --soft origin/bkkmr2
# git commit -a -m "Merge review: ~~~"
# git log origin/sandbox/jaegeuk/[branch name]
# go Gerrit
