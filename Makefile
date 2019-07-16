# Build U-Boot for x86
.POSIX:

TAG=2019.10
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("x86_64", $(MK_ARCH))
	undefine CROSS_COMPILE
	export KVM=-enable-kvm -cpu native
else
	export CROSS_COMPILE=/usr/bin/x86_64-linux-gnu-
	export KVM=-cpu core2duo
endif
undefine MK_ARCH

export KVM=-cpu core2duo

export LOCALVERSION:=-P$(REVISION)
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
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
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
	cd denx && git checkout master && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout origin/master -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

check:
	qemu-system-x86_64 $(KVM) -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0
check-s:
	qemu-system-x86_64 $(KVM) -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 -S \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0

clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:

uninstall:
