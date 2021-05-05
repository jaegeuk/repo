#!/bin/bash

entry=`grep jaegeuk /etc/sudoers`

if [ -z "$entry" ]; then
	echo "jaegeuk	ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

mkdir /home/jaegeuk/.ssh
chown jaegeuk:jaegeuk /home/jaegeuk/.ssh
cp authorized_keys /home/jaegeuk/.ssh/
chown jaegeuk:jaegeuk /home/jaegeuk/.ssh/authorized_keys
cp bashrc /root/.bashrc

cp -r /home/jaegeuk/SETUP /root/
cp /root/SETUP/INSTALL /root/
cp /root/SETUP/mk_kernel.sh /root/

cat /root/SETUP/grub >> /etc/default/grub

sudo git config --global user.email "jaegeuk@kernel.org"
sudo git config --global user.name "Jaegeuk Kim"
sudo git config --global merge.tool "vimdiff"
sudo git config pull.rebase true
