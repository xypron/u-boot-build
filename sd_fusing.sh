#!/bin/sh
sudo dd conv=fsync,notrunc if=u-boot-sunxi-with-spl.bin of=$1 bs=8k seek=1
sudo eject $1
