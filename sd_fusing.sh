#!/bin/sh
dd conv=fsync,notrunc if=u-boot-sunxi-with-spl.bin of=$1 bs=1024 seek=8
sudo eject $1
