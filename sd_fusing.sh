#!/bin/sh
sudo dd conv=fsync,notrunc if=spl/u-boot-spl.bin of=$1 seek=34
sudo dd conv=fsync,notruncif=u-boot.itb of=$1 seek=2082
sudo eject $1
