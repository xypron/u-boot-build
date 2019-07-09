# Build U-Boot for QEMU RISC-V
.POSIX:

TAG=2019.10
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
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
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
	qemu-system-riscv64 -machine virt -m 1G \
	-kernel denx/u-boot -nographic \
	-device virtio-net-device,netdev=user \
	-netdev user,id=user,tftp=tftp

debug:
	qemu-system-riscv64 -machine virt \
	-kernel denx/u-boot -nographic -gdb tcp:1234 \
	-device virtio-net-device,netdev=usernet \
	-netdev user,id=usernet

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
