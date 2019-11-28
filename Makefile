# Build U-Boot for BananaPi
.POSIX:

TAG=2020.01
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

export TTYDEVICE="/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.3:1.0-port0"

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

MK_ARCH="${shell uname -m}"
ifeq ("armv7l", $(MK_ARCH))
	undefine CROSS_COMPILE
else ifeq ("armv7", $(MK_ARCH))
	export CROSS_COMPILE=e
else
	export CROSS_COMPILE=arm-linux-gnueabihf-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)
export BUILD_ROM=y

ifeq (, $(shell which gmake))
	export MAKE=make
else
	export MAKE=gmake
endif
ifeq (, $(shell which gpg2))
	export GPG=gpg
else
	export GPH=gpg2
endif

al:
	$(MAKE) prepare
	$(MAKE) build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch origin || true)
	$(GPG) --list-keys 87F9F635D31D7652 || \
	$(GPG) --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d tftp || mkdir tftp

build-ipxe:
	cd ipxe && (git am --abort || true)
	cd ipxe && (git fetch origin || true)
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
	cd ipxe/src && $(MAKE) bin-arm32-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe
	mkdir -p tftp /
	cp ipxe/src/bin-arm32-efi/snp.efi tftp/

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f tftp/snp.efi || $(MAKE) build-ipxe
	cd denx && (git fetch origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase origin/master
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && $(MAKE) mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

check:

flash:
	relay-card off
	sd-mux-ctrl -e xypron-0002 -td
	sd-mux-ctrl -e xypron-0002 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/u-boot-sunxi-with-spl.bin \
	of=/dev/sda bs=8k seek=1
	sleep 1
	sd-mux-ctrl -e xypron-0002 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

clean:
	cd ipxe/src && make clean
	rm -rf ipxe/src/bin-arm32-efi
	cd denx && $(MAKE) mrproper
	rm -f tftp/snp.efi

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp denx/u-boot-sunxi-with-spl.bin $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp boot.scr $(DESTDIR)/usr/lib/u-boot/bananapi/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/bananpi/
