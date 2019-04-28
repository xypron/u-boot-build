# Build U-Boot for Pine A64 LTS
.POSIX:

TAG=2019.07
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

all:
	make prepare
	make atf
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && git fetch
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
	cd arm-trusted-firmware && (git fetch origin || true)
	cd arm-trusted-firmware && git rebase
	cd arm-trusted-firmware && BL31= make PLAT=sun50i_a64 DEBUG=1 bl31

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
	mkdir -p tftp/
	cp ipxe/src/bin-arm64-efi/snp.efi tftp/snp-arm64.efi

build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && git rebase
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

clean:
	test ! -d denx || ( cd denx && make mrproper )
	test ! -d arm-trusted-firmware || \
	( cd arm-trusted-firmware && make distclean )

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp denx/u-boot-sunxi-with-spl.bin \
	$(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/

i:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp /tmp/build/u-boot-sunxi-with-spl.bin \
	$(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/pine-a64-lts/
