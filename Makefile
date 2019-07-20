# Build U-Boot for BananaPi
.POSIX:

TAG=2019.10
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

all:
	which gmake && gmake prepare || make prepare
	which gmake && gmake build || make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch origin || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
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
	cd ipxe/src && make bin-arm32-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe
	mkdir -p tftp /
	cp ipxe/src/bin-arm32-efi/snp.efi tftp/

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f tftp/snp.efi || make build-ipxe
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
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

check:

clean:
	cd ipxe/src && make clean
	rm -rf ipxe/src/bin-arm32-efi
	cd denx && make mrproper
	rm -f tftp/snp.efi

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp denx/u-boot-sunxi-with-spl.bin $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp boot.scr $(DESTDIR)/usr/lib/u-boot/bananapi/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/bananpi/
