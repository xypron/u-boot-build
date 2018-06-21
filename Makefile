# Build U-Boot for the Tinker Board
.POSIX:

TAG=2018.05
TAGPREFIX=v

NPROC=${shell nproc}

MK_ARCH="${shell uname -m}"
ifneq ("x86_64", $(MK_ARCH))
	$(error only builds on x86_64)
endif
undefine MK_ARCH
export CROSS_COMPILE=aarch64-linux-gnu-

all:
	which gmake && gmake prepare || make prepare
	which gmake && gmake build || make build

prepare:
	test -d rkbin/.git || \
	git submodule init rkbin && git submodule update rkbin
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch origin || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --recv-key 87F9F635D31D7652

build:
	cd denx && (git fetch origin || true)
	cd denx && (git fetch agraf || true)
	cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	# cd denx && ../patch/patch-$(TAG)
	cd denx && make mrproper
	cd denx && make firefly-rk3399_defconfig
	cd denx && make -j$(NPROC)
	cd denx && make

check:

clean:
	cd denx && make distclean
	rm -f *.img

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/
	cd rkbin && (git fetch || true)
	cd rkbin && git checkout master && git rebase
	cd rkbin && git checkout 784b3ef28e746e6e3ddb6fe13421a42c374c9bb4
	denx/tools/mkimage -n rk3399 -T rksd \
	-d rkbin/rk33/rk3399_ddr_800MHz_v1.08.bin idbloader.img
	cat rkbin/rk33/rk3399_miniloader_v1.06.bin >> idbloader.img
	rkbin/tools/trust_merger trust.ini	
	rkbin/tools/loaderimage --pack --uboot denx/u-boot-dtb.bin uboot.img \
	  0x200000
	cp idbloader.img $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/
	cp trust.img $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/	
	cp uboot.img $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/firefly-rk3399/

uninstall:
