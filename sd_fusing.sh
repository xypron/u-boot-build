#!/bin/sh
sudo dd conv=fsync,notrunc if=u-boot.img of=$1 bs=1024 seek=32
dd if=SPL of=$1 bs=1k seek=1
dd if=u-boot.img of=$1 bs=1k seek=69
sudo eject $1
