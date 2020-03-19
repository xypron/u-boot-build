# Build U-Boot for Pine A64 LTS
.POSIX:

TAG=2020.04
TAGPREFIX=v
REVISION=001

MESON_TOOLS_TAG=v0.1

NPROC=${shell nproc}

MK_ARCH="${shell uname -m}"
ifeq ("aarch64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=aarch64-linux-gnu-
endif
undefine MK_ARCH

export ARCH=arm64

export LOCALVERSION:=-D$(REVISION)

export BL31=../arm-trusted-firmware/build/sun50i_a64/debug/bl31.bin

export TTYDEVICE="/dev/serial/by-path/platform-3f980000.usb-usb-0:1.1.3:1.0-port0"

all:
	make prepare
	make atf
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch --prune origin || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -d arm-trusted-firmware || git clone -v \
	https://github.com/ARM-software/arm-trusted-firmware.git \
	arm-trusted-firmware
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	( git config --global user.email "somebody@example.com"  && \
	git config --global user.name "somebody" )

atf:
	cd arm-trusted-firmware && (git fetch --prune origin || true)
	cd arm-trusted-firmware && git rebase
	cd arm-trusted-firmware && BL31= make PLAT=sun50i_a64 DEBUG=1 bl31

build-ipxe:
	cd ipxe && (git am --abort || true)
	cd ipxe && (git fetch --prune origin || true)
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
	cd ipxe/src && make bin-arm64-efi/snp.efi -j $(NPROC) \
	EMBED=config/local/chain.ipxe
	mkdir -p tftp/
	cp ipxe/src/bin-arm64-efi/snp.efi tftp/snp-arm64.efi

build:
	cd patch && (git fetch --prune origin || true)
	cd patch && (git checkout efi-next)
	cd patch && git rebase
	test -f ipxe/src/bin-arm64-efi/snp.efi || make build-ipxe
	cd denx && (git fetch --prune origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j $(NPROC)

clean:
	test ! -d denx || ( cd denx && make mrproper )
	test ! -d arm-trusted-firmware || \
	( cd arm-trusted-firmware && make distclean )

flash:
	relay-card off
	sd-mux-ctrl -v 0 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/u-boot-sunxi-with-spl.bin \
	of=/dev/sda bs=8k seek=1
	sleep 1
	sd-mux-ctrl -v 0 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp denx/u-boot-sunxi-with-spl.bin \
	$(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
