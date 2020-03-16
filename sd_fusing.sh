#!/bin/sh
sudo dd conv=fsync,notrunc if=flash-image.bin of=$1 bs=512 seek=1
sudo eject $1
