# Build U-Boot for the Rock Pi 4A
.POSIX:

TAG=next
TAGPREFIX=v
TTYDEVICE=/dev/serial/by-path/platform-xhci-hcd.1-usb-0:2.4.4.4:1.0-port0
SDMUXDISK=/dev/sda
export BL31="$(shell pwd)/trusted-firmware-a/build/rk3399/release/bl31/bl31.elf"

NPROC=${shell nproc}

export CROSS_COMPILE=aarch64-linux-gnu-
export M0_CROSS_COMPILE=arm-none-eabi-
export BL31=/usr/lib/arm-trusted-firmware/rk3399/bl31.elf

all:
	make build

trusted-firmware-a:
	git clone https://github.com/TrustedFirmware-A/trusted-firmware-a.git

denx:
	git clone https://source.denx.de/u-boot/u-boot.git denx

tfa: trusted-firmware-a
	cd trusted-firmware-a && \
	git fetch && \
	git reset --hard lts-v2.12.8 && \
	../patch/patch-tfa.sh
	rm -rf trusted-firmware-a/build
	cd trusted-firmware-a && \
	make realclean && \
	unset BL31 && \
	make -j$(NPROC) PLAT=rk3399 bl31

build: denx
	cd denx && \
	make rock-pi-4-rk3399_defconfig && \
	make -j$(NPROC)
	
flash:
	switch off rock4a
	sd-mux-ctrl -e xypron-0005 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/u-boot-rockchip.bin \
	of=$(SDMUXDISK) bs=32k seek=1
	sleep 1
	sd-mux-ctrl -e xypron-0005 -td
	switch on rock4a
	picocom $(TTYDEVICE) --baud 1500000

run:
	sd-mux-ctrl -e xypron-0005 -td
	switch on rock4a
	picocom $(TTYDEVICE) --baud 1500000
