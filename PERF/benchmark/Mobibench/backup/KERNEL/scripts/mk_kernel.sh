#!/bin/sh

export CONCURRENCY_LEVEL=4
make-kpkg --initrd --revision=1.0 kernel_image
