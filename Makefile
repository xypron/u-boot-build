# Build U-Boot for the Rock Pi 4A
.POSIX:

TAG=next
TAGPREFIX=v

NPROC=${shell nproc}

export CROSS_COMPILE=aarch64-linux-gnu-

all:
	make tfa
	make build

trusted-firmware-a:
	git clone https://github.com/TrustedFirmware-A/trusted-firmware-a.git

tfa: trusted-firmware-a
	cd trusted-firmware-a && \
	git fetch && \
	git reset --hard origin/main


build:
	
