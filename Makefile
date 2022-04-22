# Build U-Boot for PolarFire Icicle board
.POSIX:

TAG=2022.04
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

MK_ARCH="${shell uname -m}"
ifeq ("riscv64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=riscv64-linux-gnu-
endif
undefine MK_ARCH

all:
	make prepare
	make build
