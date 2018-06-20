#!/bin/sh
sudo dd conv=fsync,notrunc if=idbloader.img of=$1 bs=32k seek=1
sudo dd conv=fsync,notrunc if=uboot.img of=$1 bs=64k seek=128
sudo dd conv=fsync,notrunc if=trust.img of=$1 bs=64k seek=192
sudo eject $1
