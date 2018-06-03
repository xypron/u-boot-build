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
ifeq ("aarch64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=aarch64-linux-gnu-
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
	test -d rkbin/.git || \
	git submodule init rkbin && git submodule update rkbin
	test -d rkdeveloptool/.git || \
	git submodule init rkdeveloptool && git submodule update rkdeveloptool
	test -d arm-trusted-firmware/.git || \
	git submodule init arm-trusted-firmware && \
	git submodule update arm-trusted-firmware
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch origin || true)
	cd denx && \
	  (git remote add agraf https://github.com/agraf/u-boot.git || true)
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

build-arm-trusted-firmware:
	cd arm-trusted-firmware && make realclean
	cd arm-trusted-firmware && make PLAT=rk3399 bl31

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
	mkdir -p ipxe/src/config/local/
	cp config/*.h ipxe/src/config/local/
	cp config/*.ipxe ipxe/src/config/local/
	cd ipxe/src && make bin-arm64-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe

build-rkdeveloptool:
	cd rkdeveloptool && autoreconf -i
	cd rkdeveloptool && ./configure
	cd rkdeveloptool && make

build:
	test -f ipxe/src/bin-arm64-efi/snp.efi || make build-ipxe
	cp ipxe/src/bin-arm64-efi/snp.efi tftp
	test -f rkdeveloptool/rkdeveloptool || make build-rkdeveloptool
	test -f arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf || \
	make build-arm-trusted-firmware
	cp arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf denx/
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin || true)
	cd denx && (git fetch agraf || true)
	# cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	# grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	# cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && git checkout master
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout agraf/efi-next -b pre-build
	cd denx && git rebase origin/master
	cd denx && ( git branch -D build || true )
	cd denx && ( git am --abort || true )
	cd denx && git checkout -b build
	# cd denx && ../patch/patch-$(TAG)
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)
	cd denx && make u-boot.itb

check:

clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/
	denx/tools/mkimage -n rk3399 -T rksd -d denx/spl/u-boot-spl.bin \
	  $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/idbspl.img
	cp denx/u-boot.itb $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/u-boot.itb
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/

uninstall:
