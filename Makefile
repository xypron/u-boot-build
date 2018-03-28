# Build U-Boot for Odroid C2
.POSIX:

TAG=2018.03
TAGPREFIX=v
REVISION=002

MESON_TOOLS_TAG=v0.1

MK_ARCH="${shell uname -m}"
ifneq ("armv7l", $(MK_ARCH))
	export ARCH=arm
	export CROSS_COMPILE=arm-linux-gnueabihf-
endif
undefine MK_ARCH

export LOCALVERSION:=-R$(REVISION)

all:
	make prepare
	make build
	make fip_create
	make sign

prepare:
	test -d patch || git submodule update
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && git fetch
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
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
	cd denx && make -j6
	mkimage -T script -C none -n 'bootefi snp.efi' \
	-d config/boot.txt boot.scr

clean:
	test ! -d denx        || ( cd denx && make clean )

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp denx/u-boot-sunxi-with-spl.bin $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/bananapi/
	cp boot.scr $(DESTDIR)/usr/lib/u-boot/bananapi/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/bananpi/
