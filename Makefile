# Build U-Boot for BananaPi
.POSIX:

TAG=2020.01
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
else ifeq ("armv6l", $(MK_ARCH))
	undefine CROSS_COMPILE
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
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d tftp || mkdir tftp

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
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

clean:
	cd ipxe/src && make clean
	rm -rf ipxe/src/bin-arm32-efi
	cd denx && $(MAKE) mrproper
	rm -f tftp/snp.efi

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/rpi0w/
	cp denx/u-boot.bin $(DESTDIR)/usr/lib/u-boot/rpi0w/
	cp boot.scr $(DESTDIR)/usr/lib/u-boot/rpi0w/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/rpi0w/
