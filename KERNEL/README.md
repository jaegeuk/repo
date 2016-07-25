--------------
Kernel Compile
--------------

1. Packages

 apt-get install kernel-package libssl-dev libncurses5-dev

2. Ubuntu kernel

  apt-get source linux-image-$(uname -r)

3. Symlinks

  ubuntu/vbox# ln -s ../include ./r0drv/include

  ubuntu/vbox# ln -s ../include ./vboxsf/include

  ubuntu/vbox# ln -s ../include ./vboxguest/include

  ubuntu/vbox# ln -s ../include ./vboxvideo/include

  ubuntu/vbox/vboxguest# ln -s ../r0drv/

4. Compile

  ./mk_kernel.sh
