# Build U-Boot for the Wandboard
.POSIX:

TAG=2019.07
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
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch origin || true)
	cd denx && \
	  (git remote add agraf https://github.com/agraf/u-boot.git || true)
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --recv-key 87F9F635D31D7652
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )

build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin || true)
	cd denx && (git fetch agraf || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout agraf/efi-next -b pre-build
	cd denx && git rebase origin/master
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

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/wandboard/
	cp denx/SPL $(DESTDIR)/usr/lib/u-boot/wandboard/
	cp denx/u-boot.img $(DESTDIR)/usr/lib/u-boot/wandboard/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/wandboard/

uninstall:
