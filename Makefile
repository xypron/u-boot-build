# Build U-Boot for Odroid C2
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

export LOCALVERSION:=-D$(REVISION)

export BL31:=$(CURDIR)/trusted-firmware-a/build/gxbb/debug/bl31.bin

all:
	make prepare
	make build
	make atf
	make fip_create
	make sign

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot denx
	cd denx && git fetch
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -d hardkernel || git clone -v \
	https://github.com/hardkernel/u-boot.git hardkernel
	cd hardkernel && git fetch
	test -d meson-tools || git clone -v \
	https://github.com/afaerber/meson-tools.git meson-tools
	cd meson-tools && git fetch
	test -d trusted-firmware-a || \
	git clone https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git
	cd trusted-firmware-a && git fetch
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )

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
	cd ipxe/src && make bin-arm64-efi/snp.efi -j $(NPROC) \
	EMBED=config/local/chain.ipxe
	cp ipxe/src/bin-arm64-efi/snp.efi tftp

build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f ipxe/src/bin-arm64-efi/snp.efi || make build-ipxe
	cd denx && (git fetch origin || true)
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

atf:
	cd trusted-firmware-a && git fetch
	cd trusted-firmware-a && git checkout v2.2
	cd trusted-firmware-a && git reset --hard v2.2
	cd trusted-firmware-a && make DEBUG=1 PLAT=gxbb bl31

fip_create:
	cd hardkernel && git fetch
	cd hardkernel && git reset --hard
	cd hardkernel && git checkout f9a34305b098cf3e78d2e53f467668ba51881e91
	cd hardkernel && ( git branch -D build || true )
	cd hardkernel && git checkout -b build
	test ! -f patch/patch-hardkernel || \
	  ( cd hardkernel && ../patch/patch-hardkernel )
	cd hardkernel/tools/fip_create && make
	cp hardkernel/tools/fip_create/fip_create hardkernel/fip
	cp denx/u-boot.bin hardkernel/fip/gxb/bl33.bin
	cd hardkernel/fip/gxb && ../fip_create \
	  --bl30 bl30.bin --bl301 bl301.bin \
	  --bl31 $(BL31) --bl33 bl33.bin fip.bin
	cd hardkernel/fip/gxb && cat bl2.package fip.bin > boot_new.bin

sign:
	cd meson-tools && git fetch
	cd meson-tools && git verify-tag $(MESON_TOOLS_TAG) 2>&1 | \
	grep '174F 0347 1BCC 221A 6175  6F96 FA2E D12D 3E7E 013F'
	cd meson-tools && git reset --hard
	cd meson-tools && git checkout $(MESON_TOOLS_TAG)
	cd meson-tools && make CC=gcc
	meson-tools/amlbootsig hardkernel/fip/gxb/boot_new.bin u-boot.bin

clean:
	test ! -d denx        || ( cd denx && make clean )
	test ! -d hardkernel  || ( cd hardkernel && make clean )
	test ! -d meson-tools || ( cd meson-tools && make clean )
	rm -f u-boot.bin

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/odroid-c2/
	dd if=u-boot.bin of=$(DESTDIR)/usr/lib/u-boot/odroid-c2/u-boot.bin skip=96
	cp hardkernel/sd_fuse/bl1.bin.hardkernel $(DESTDIR)/usr/lib/u-boot/odroid-c2/
	cp hardkernel/sd_fuse/sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/odroid-c2/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/odroid-c2/
