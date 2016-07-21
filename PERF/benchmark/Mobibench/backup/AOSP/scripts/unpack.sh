#!/bin/bash

# git clone https://github.com/xiaolu/mkbootimg_tools.git

~/mkbootimg_tools/mkboot boot.img boot.extracted

unpackbootimg -i boot.img >/dev/null
dd if=boot.img-zImage bs=1 skip=$(LC_ALL=C grep -a -b -o $'\x1f\x8b\x08\x00\x00\x00\x00\x00' boot.img-zImage | cut -d ':' -f 1) 2>/dev/null | zgrep -a 'Linux version' > Linux_version
cat Linux_version
