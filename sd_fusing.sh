#!/bin/sh
sudo dd conv=fsync,notrunc if=fip.bin of=$1 bs=512 seek=1
sudo eject $1
