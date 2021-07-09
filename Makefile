# Build U-Boot for QEMU RISC-V 64bit
.POSIX:

TAG=2020.10
TAGPREFIX=v
REVISION=001

MESON_TOOLS_TAG=v0.1

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("riscv64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=riscv64-linux-gnu-
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
	https://gitlab.denx.de/u-boot/u-boot.git
	cd denx && (git fetch || true)
	test -d opensbi || git clone -v \
	https://github.com/riscv/opensbi.git
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	mkdir -p tftp

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j6

check:
	test -f riscv64.img || \
	qemu-system-riscv64 -machine virt -m 1G -nographic \
	-bios denx/u-boot -smp cores=2 -gdb tcp::1234 \
	-device virtio-net-device,netdev=net0 \
	-netdev user,id=net0,tftp=tftp \
	-device virtio-rng-pci
	test ! -f riscv64.img || \
	qemu-system-riscv64 -machine virt -m 1G -nographic \
	-bios denx/u-boot -smp cores=2 -gdb tcp::1234 \
	-device virtio-net-device,netdev=net0 \
	-netdev user,id=net0,tftp=tftp \
	-drive if=none,file=riscv64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0 \
	-device virtio-rng-pci

sct:
	test -f sct-riscv64.img || \
	make sct-prepare
	qemu-system-riscv64 $(KVM) -machine virt -m 1G \
	-bios denx/u-boot.bin -nographic -gdb tcp::1234 \
	-device virtio-net-device,netdev=net0 \
	-netdev user,id=net0,tftp=tftp \
	-device virtio-rng-pci \
	-drive if=none,file=sct-riscv64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0
	mkdir -p sct-results

sbi:
	cd opensbi && make PLATFORM=generic FW_PAYLOAD_PATH=../denx/u-boot.bin

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
