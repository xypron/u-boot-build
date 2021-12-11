# Build U-Boot for the OrangePi PC
.POSIX:

TAG=2022.01
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

MK_ARCH="${shell uname -m}"
ifeq ("armv7l", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=arm-linux-gnueabihf-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)
export BUILD_ROM=y

export TTYDEVICE="/dev/serial/by-path/platform-3f980000.usb-usb-0:1.1.3:1.0-port0"
export SDMUXDISK="/dev/disk/by-id/sd-mux-ctrl-0"

all:
	which gmake && gmake prepare || make prepare
	which gmake && gmake build || make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch origin --prune || true)
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --recv-key 87F9F635D31D7652
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	mkdir -p tftp

build-ipxe:
	cd ipxe && (git am --abort || true)
	cd ipxe && (git fetch origin --prune || true)
	cd ipxe && (git am --abort || true)
	cd ipxe && git reset --hard
	cd ipxe && git checkout master
	cd denx && ( git am --abort || true )
	cd ipxe && git rebase
	cd ipxe && ( git branch -D build || true )
	cd ipxe && git checkout -b build
	cd ipxe && ../patch/patch-ipxe.sh
	mkdir -p ipxe/src/config/local/
	cp config/*.h ipxe/src/config/local/
	cp config/*.ipxe ipxe/src/config/local/
	cd ipxe/src && make bin-arm32-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe

build:
	test -f ipxe/src/bin-arm32-efi/snp.efi || make build-ipxe
	cp ipxe/src/bin-arm32-efi/snp.efi tftp
	cd patch && (git fetch origin --prune || true)
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

clean:
	cd denx && make distclean
	rm tftp/snp.efi

flash:
	relay-card off
	sd-mux-ctrl -e xypron-0001 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/u-boot-sunxi-with-spl.bin \
	of=$(SDMUXDISK) bs=8k seek=1
	sleep 1
	sd-mux-ctrl -e xypron-0001 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

run:
	sd-mux-ctrl -e xypron-0001 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

check:
	relay-card off
	sleep 3
	sd-mux-ctrl -e xypron-0001 -td
	sleep 1
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/orangepi-pc/
	cp denx/u-boot-sunxi-with-spl.bin $(DESTDIR)/usr/lib/u-boot/orangepi-pc/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/orangepi-pc/

uninstall:
