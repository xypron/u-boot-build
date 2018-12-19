# Build U-Boot for QEMU arm64
.POSIX:

TAG=2018.11
TAGPREFIX=v
REVISION=001

MESON_TOOLS_TAG=v0.1

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("aarch64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=aarch64-linux-gnu-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)

export BL33=$(CURDIR)/denx/u-boot.bin
export SCP_BL2=$(CURDIR)/binaries-marvell/mrvl_scp_bl2_mss_ap_cp1_a8040.img

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
	cd denx && (git remote -v | grep agraf || \
	git remote add agraf https://github.com/agraf/u-boot.git)
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d binaries-marvell || \
	git clone https://github.com/MarvellEmbeddedProcessors/binaries-marvell
	test -d mv-ddr || git clone \
	https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell.git mv-ddr
	test -d atf-marvell || \
	git clone https://github.com/MarvellEmbeddedProcessors/atf-marvell.git


build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout $(TAGPREFIX)$(TAG))
	cd patch && git rebase
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
	cd denx && make -j6

atf:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout $(TAGPREFIX)$(TAG))
	cd patch && git rebase
	cd binaries-marvell && git fetch
	true
	cd binaries-marvell && git checkout binaries-marvell-armada-18.06
	cd binaries-marvell && \
	git reset --hard origin/binaries-marvell-armada-18.06
	cd mv-ddr && git fetch
	cd mv-ddr && git checkout mv_ddr-armada-18.09
	cd mv-ddr && git reset --hard origin/mv_ddr-armada-18.09
	test ! -f patch/patch-mv_ddr-armada-18.09 || \
	(cd mv-ddr && ../patch/patch-mv_ddr-armada-18.09)
	cd atf-marvell && git fetch
	cd atf-marvell && git checkout atf-v1.5-armada-18.09
	cd atf-marvell && git reset --hard origin/atf-v1.5-armada-18.09
	cd atf-marvell && make USE_COHERENT_MEM=0 LOG_LEVEL=20 \
	MV_DDR_PATH=../mv-ddr PLAT=a80x0_mcbin all fip


clean:
	test ! -d denx || ( cd denx && make clean )

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/macchiatobin/
	cp atf-marvell/build/a80x0_mcbin/release/flash-image.bin \
	$(DESTDIR)/usr/lib/u-boot/macchiatobin/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/macchiatobin/

uninstall:

uninstall:
