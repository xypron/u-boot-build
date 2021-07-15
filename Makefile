# Build U-Boot for MacchiatoBin
.POSIX:

TAG=2021.10
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("aarch64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=aarch64-linux-gnu-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)

export DEVICE_TREE=armada-8040-mcbin
export BL33=$(CURDIR)/denx/u-boot.bin
export SCP_BL2=$(CURDIR)/binaries-marvell/mrvl_scp_bl2.img

all:
	make prepare
	make build
	make atf

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d binaries-marvell || \
	git clone https://github.com/MarvellEmbeddedProcessors/binaries-marvell
	test -d mv-ddr || git clone \
	https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell.git mv-ddr
	test -d trusted-firmware-a || \
	git clone https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git


build:
	cd patch && ( git am --abort || true )
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && git rebase origin/efi-next
	cd denx && ( git am --abort || true )
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase origin/master
	cd denx && ( git branch -D pre-build || true )
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b pre-build
	cd denx && git checkout -b build
	test ! -f patch/patch-efi-next.sh || \
	(cd denx && ../patch/patch-efi-next.sh)
	cd denx && make distclean
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

atf:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && git rebase
	cd binaries-marvell && git fetch
	true
	cd binaries-marvell && git checkout binaries-marvell-armada-18.12
	cd binaries-marvell && \
	git reset --hard origin/binaries-marvell-armada-18.12
	cd mv-ddr && git fetch
	cd mv-ddr && git checkout mv_ddr-armada-atf-mainline
	cd mv-ddr && git reset --hard origin/mv_ddr-armada-atf-mainline
	test ! -f patch/patch-mv_ddr-armada-atf-mainline || \
	(cd mv-ddr && ../patch/patch-mv_ddr-armada-atf-mainline)
	cd trusted-firmware-a && git fetch
	cd trusted-firmware-a && git checkout v2.2
	cd trusted-firmware-a && git reset --hard v2.2
	cd trusted-firmware-a && make USE_COHERENT_MEM=0 LOG_LEVEL=20 \
	MV_DDR_PATH=../mv-ddr PLAT=a80x0_mcbin all fip

clean:
	test ! -d denx || ( cd denx && make clean )

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/macchiatobin/
	cp trusted-firmware-a/build/a80x0_mcbin/release/flash-image.bin \
	$(DESTDIR)/usr/lib/u-boot/macchiatobin/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/macchiatobin/

uninstall:
