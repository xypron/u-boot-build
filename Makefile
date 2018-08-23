# Build U-Boot for Versatile Express V2P-CA15-CA7 (TC2)
.POSIX:

TAG=2018.07
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

MK_ARCH="${shell uname -m}"
ifeq ("armv7l", $(MK_ARCH))
	undefine CROSS_COMPILE
else
	export CROSS_COMPILE=arm-linux-gnueabihf-
endif
undefine MK_ARCH

export LOCALVERSION:=-D$(REVISION)
export BUILD_ROM=y

all:
	which gmake && gmake prepare || make prepare
	which gmake && gmake build || make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && (git fetch origin || true)
	cd denx && \
	  (git remote add agraf https://github.com/agraf/u-boot.git || true)
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
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
	test -f ipxe/src/bin-arm32-efi/snp.efi || make build-ipxe
	cp ipxe/src/bin-arm32-efi/snp.efi tftp
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin || true)
	cd denx && (git fetch agraf || true)
	# cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	# grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	# cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && git checkout master && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout agraf/efi-next -b pre-build
	cd denx && git rebase origin/master
	cd denx && ( git branch -D build || true )
	cd denx && ( git am --abort || true )
	cd denx && git checkout -b build
	# cd denx && ../patch/patch-$(TAG)
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

check:
	QEMU_AUDIO_DRV=none qemu-system-arm \
	-M vexpress-a15 -cpu cortex-a15 -kernel denx/u-boot \
	-net user -net nic,model=lan9118 \
	-m 1024M --nographic \
	-drive if=sd,file=img.vexpress,media=disk,format=raw

check-gdb:
	pkill qemu-system-arm || true
	pkill agent-proxy || true
	agent-proxy 4440^1234 localhost 2000 &
	QEMU_AUDIO_DRV=none qemu-system-arm \
	-M vexpress-a15 -cpu cortex-a15 -kernel denx/u-boot \
	-net user -net nic,model=lan9118 \
	-m 1024M --nographic \
	-drive if=sd,file=img.vexpress,media=disk,format=raw \
	-chardev socket,id=char0,port=2000,host=localhost,ipv4,server \
	-serial chardev:char0 &
	sleep 1
	telnet localhost 4440 || true
	pkill qemu-system-arm || true
	pkill agent-proxy || true
clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:

uninstall:
