#!/bin/sh
sudo dd conv=fsync,notrunc if=u-boot.img of=$1 bs=1024 seek=32
sudo eject $1
