#!/bin/sh
sudo dd conv=fsync,notrunc if=u-boot-sunxi-with-spl.bin of=/dev/sda bs=8k seek=1
sudo eject $1
