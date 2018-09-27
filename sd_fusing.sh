#!/bin/sh
sudo dd if=SPL of=$1 bs=1k seek=1
sudo dd if=u-boot.img of=$1 bs=1k seek=69
sudo eject $1
