# Build U-Boot for QEMU arm
.POSIX:

TAG=2018.11
TAGPREFIX=v
REVISION=001

MESON_TOOLS_TAG=v0.1

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("arm", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=arm-linux-gnueabihf-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)

all:
	make prepare
	make build

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
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	mkdir -p tftp

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
	cd ipxe/src && make bin-arm32-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f ipxe/src/bin-arm32-efi/snp.efi || make build-ipxe
	cp ipxe/src/bin-arm32-efi/snp.efi tftp/snp-arm32.efi
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
	cd denx && make -j6

check:
	test -f arm32.img || \
	qemu-system-arm -machine virt -cpu cortex-a15 -m 1G -smp cores=2 \
	-bios denx/u-boot.bin -nographic \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0
	test ! -f arm32.img || \
	qemu-system-arm -machine virt -cpu cortex-a15 -m 1G -smp cores=2 \
	-bios denx/u-boot.bin -nographic \
	-netdev user,hostfwd=tcp::10022-:22,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 \
	-drive if=none,file=arm32.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-drive,drive=mydisk,bus=ahci.0

debug:
	qemu-system-arm -machine virt -cpu cortex-a15 \
	-bios denx/u-boot.bin -nographic -gdb tcp::1234 -netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
