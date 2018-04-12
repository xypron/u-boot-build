#!/bin/sh

sudo dd conv=fsync,notrunc if=spl.bin of=$1 bs=1024 seek=32
# CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR=0x100
sudo dd conv=fsync,notrunc if=u-boot-dtb.img of=$1 bs=1024 seek=128
sudo eject $1
