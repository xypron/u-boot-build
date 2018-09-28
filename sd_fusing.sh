#!/bin/sh
sudo dd iflag=dsync oflag=dsync conv=notrunc if=SPL of=$1 bs=1k seek=1
sudo dd iflag=dsync oflag=dsync conv=notrunc if=u-boot.img of=$1 bs=1k seek=69
sudo eject $1
