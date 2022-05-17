#!/bin/sh

set -e

expected='2e32fdea-74ee-4b03-a243-94d3e04a2cf3'
source_file='u-boot.img'

echo "Checking partition $1"
sudo blkid -s PARTUUID $1 | grep $expected > /dev/null || \
(echo "Wrong partition type, expected $expected";false)

echo "Copying $source_file to $1"
sudo dd if=$source_file of=$1 bs=1M conv=fsync,notrunc
echo "Done"
