# Build U-Boot for HiFive Unmateched
.POSIX:

TAG=2022.01
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

MK_ARCH="${shell uname -m}"
ifeq ("riscv64", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=riscv64-linux-gnu-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)

export OPENSBI=../opensbi/build/platform/generic/firmware/fw_dynamic.bin

all:
	make prepare
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://source.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch || true)
	test -d opensbi || git clone -v \
	https://github.com/riscv/opensbi.git
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	mkdir -p tftp

sbi:
	cd opensbi && (git fetch origin || true)
	cd opensbi && (git am --abort || true)
	cd opensbi && (git checkout master)
	cd opensbi && git rebase
	cd opensbi && make -j $(NPROC) \
	PLATFORM=generic FW_PAYLOAD_PATH=../denx/u-boot.bin

build:
	test -f denx/ubootefi.var || cp config ubootefi.var denx
	test -f opensbi/$(OPENSBI) || make sbi
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
	cd denx && git reset --hard origin/master
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j $(NPROC)

clean:
	test ! -d denx || ( cd denx && make clean )

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/unmatched/
	cp denx/spl/u-boot-spl.bin $(DESTDIR)/usr/lib/u-boot/unmatched/
	cp denx/u-boot.itb $(DESTDIR)/usr/lib/u-boot/unmatched/
	cp denx/.config $(DESTDIR)/usr/lib/u-boot/unmatched/config
	cp sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/unmatched/

uninstall:
