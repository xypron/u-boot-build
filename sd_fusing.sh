#!/bin/sh
sudo dd conv=fsync,notrunc if=idbspl.img of=$1 bs=1024 seek=32
sudo dd conv=fsync,notrunc if=u-boot.itb of=$1 bs=1024 seek=8192
sudo eject $1
