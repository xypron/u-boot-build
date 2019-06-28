# Build U-Boot for QEMU arm64
.POSIX:

TAG=2019.07
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("aarch64", $(MK_ARCH))
	undefine CROSS_COMPILE
	export KVM=-enable-kvm -cpu host
else
	export CROSS_COMPILE=aarch64-linux-gnu-
	export KVM=-cpu cortex-a53
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)

all:
	make prepare
	make atf
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git
	cd denx && (git fetch origin || true)
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -d arm-trusted-firmware || git clone -v \
	https://github.com/ARM-software/arm-trusted-firmware.git \
	arm-trusted-firmware
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	mkdir -p tftp

atf:
	cd arm-trusted-firmware && (git am --abort || true)
	cd arm-trusted-firmware && (git fetch origin || true)
	cd arm-trusted-firmware && git reset --hard
	cd arm-trusted-firmware && git checkout master
	cd arm-trusted-firmware && git reset --hard origin/master
	cd arm-trusted-firmware && make CROSS_COMPILE='' -C tools/fiptool
	cd arm-trusted-firmware && make PLAT=qemu -j $(NPROC) DEBUG=1
	rm -f bl1.bin bl2.bin bl31.bin
	cp arm-trusted-firmware/build/qemu/debug/bl1.bin bl1.bin
	cp arm-trusted-firmware/build/qemu/debug/bl2.bin bl2.bin
	cp arm-trusted-firmware/build/qemu/debug/bl31.bin bl31.bin

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cp ipxe/src/bin-arm64-efi/snp.efi tftp/snp-arm64.efi
	cd denx && (git fetch origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && ( git am --abort || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

atf-debug:
	cp denx/u-boot.bin bl33.bin
	qemu-system-aarch64 -nographic -machine virt,secure=on \
	-smp 2 -m 1024 -bios bl1.bin -cpu cortex-a53 -gdb tcp::1234 -S \
	-d unimp -semihosting-config enable,target=native
atf-run:
	cp denx/u-boot.bin bl33.bin
	test -f arm64.img || \
	qemu-system-aarch64 -nographic -machine virt,secure=on \
	-smp 2 -m 1024 -bios bl1.bin -cpu cortex-a53 -gdb tcp::1234 \
	-d unimp -semihosting-config enable,target=native \
	-netdev user,hostfwd=tcp::10022-:22,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0
	test ! -f arm64.img || \
	qemu-system-aarch64 -nographic -machine virt,secure=on \
	-smp 2 -m 1024 -bios bl1.bin -cpu cortex-a53 -gdb tcp::1234 \
	-d unimp -semihosting-config enable,target=native \
	-netdev user,hostfwd=tcp::10022-:22,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 \
	-drive if=none,file=arm64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-drive,drive=mydisk,bus=ahci.0

# -d unimp:			Log unimplemented functionality.
# -semihosting-config:		Semihosting is used to load files from the host.
# -machine virt,secure=on:	Start in EL3.

check:
	test -f arm64.img || \
	qemu-system-aarch64 -machine virt -m 1G -smp cores=2 \
	-bios denx/u-boot.bin $(KVM) -nographic -gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0
	test ! -f arm64.img || \
	qemu-system-aarch64 -machine virt -m 1G -smp cores=2 \
	-bios denx/u-boot.bin $(KVM) -nographic -gdb tcp::1234 \
	-netdev user,hostfwd=tcp::10022-:22,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 \
	-drive if=none,file=arm64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-drive,drive=mydisk,bus=ahci.0

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
