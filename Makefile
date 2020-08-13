# Build U-Boot for MaixDuino
.POSIX:

TAG=2020.10
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("riscv64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=riscv64-linux-gnu-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)
export TTY:=/dev/serial/by-id/usb-Kongou_Hikari_Sipeed-Debug_615655CD93-if00-port0

all:
	make prepare
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch origin --prune || true)
	test -d opensbi || git clone -v \
	https://github.com/riscv/opensbi.git
	cd opensbi && (git fetch origin --prune || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin --prune || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && ( git am --abort || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

sbi:
	cd opensbi && make \
	PLATFORM=kendryte/k210 \
	FW_PAYLOAD=y \
	FW_PAYLOAD_OFFSET=0x20000 \
	FW_PAYLOAD_PATH=../denx/u-boot-dtb.bin
	kflash/kflash.py -p $(TTY) -b 1500000 -B maixduino \
	opensbi/build/platform/kendryte/k210/firmware/fw_payload.bin
	picocom -b 115200 --send-cmd "sz -vv" $(TTY)

flash:
	kflash/kflash.py -p $(TTY) -b 1500000 -B maixduino denx/u-boot-dtb.bin
	picocom -b 115200 --send-cmd "sz -vv" $(TTY)

run:
	./reset.py $(TTY)
	picocom -b 115200 --send-cmd "sz -vv" $(TTY)

clean:
	test ! -d denx || ( cd denx && make clean )
	rm -rf envstore.img
	rm -rf opensbi/build

install:

uninstall:
