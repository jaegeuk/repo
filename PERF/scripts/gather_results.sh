#!/bin/bash

PERF=perf-results/
TAR=perf.tar

rm -rf $PERF/*
rsync -r --delete-excluded --delete gateway:/root/perf-results/* ./$PERF/
tar -cvf $TAR $PERF/

echo -n "Send email? "
read ans

if [ $ans -z ]; then
	echo Sent
	echo RESULTS | mutt -s "Test results" jaegeuk.kim@huawei.com -a $TAR
fi

rm $TAR
