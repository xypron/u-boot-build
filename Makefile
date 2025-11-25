# Build U-Boot for the Rock Pi 4A
.POSIX:

TAG=next
TAGPREFIX=v

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
	git reset --hard origin/main && \
	../patch/patch-tfa.sh
	cd trusted-firmware-a && \
	make realclean && \
	make PLAT=rk3399

build: denx
	cd denx && \
	make rock-pi-4-rk3399_defconfig && \
	make -j$(NPROC)
	
