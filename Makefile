# Build U-Boot for the Tinker Board
.POSIX:

TAG=2018.05
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
	test -d patch || git submodule update
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch origin || true)
	cd denx && \
	  (git remote add agraf https://github.com/agraf/u-boot.git || true)
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )

build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout $(TAGPREFIX)$(TAG))
	cd denx && git fetch
	cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && ( git am --abort || true )
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && ( git branch -D build || true )
	cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && git checkout -b build
	test ! -f patch/patch-$(TAG) || ( cd denx && ../patch/patch-$(TAG) )
	cd denx && make distclean
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

clean:
	cd denx && make distclean

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/tinker/
	denx/tools/mkimage -n rk3288 -T rksd -d denx/spl/u-boot-spl-dtb.bin \
	  $(DESTDIR)/usr/lib/u-boot/tinker/u-boot.img
	cat denx/u-boot-dtb.bin >> $(DESTDIR)/usr/lib/u-boot/tinker/u-boot.img
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/tinker/

uninstall:
