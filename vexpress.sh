#!/bin/sh
# tools/buildman/buildman --fetch-arch=arm-unknown-linux-gnueabi
cd denx
rm -rf buildman
make mrproper
tools/buildman/buildman -k -o buildman vexpress_ca15_tc2
qemu-system-arm -M vexpress-a15 -cpu cortex-a15 \
-kernel buildman/current/vexpress_ca15_tc2/u-boot \
-net user -net nic,model=lan9118 \
-m 1024M --nographic \
-drive if=sd,file=../img.vexpress,media=disk,format=raw
cd ..
