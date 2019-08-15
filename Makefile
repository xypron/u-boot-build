# Build U-Boot for x86_64
.POSIX:

TAG=2019.10
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

UID="${shell id -u $(USER)}"
MK_ARCH="${shell uname -m}"
ifeq ("x86_64", $(MK_ARCH))
	undefine CROSS_COMPILE
	export KVM=-enable-kvm -cpu native
else
	export CROSS_COMPILE=/usr/bin/x86_64-linux-gnu-
	export KVM=-cpu core2duo
endif
undefine MK_ARCH

export KVM=-cpu core2duo

export LOCALVERSION:=-P$(REVISION)
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
	cd denx && git config sendemail.aliasesfile doc/git-mailrc
	cd denx && git config sendemail.aliasfiletype mutt
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d tftp || mkdir tftp

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	cd denx && (git fetch origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout origin/master -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

sct-prepare:
	mkdir -p mnt
	sudo umount mnt || true
	rm -f sct-amd64.part1
	/sbin/mkfs.vfat -C sct-amd64.part1 1047552
	sudo mount sct-amd64.part1 mnt -o uid=$(UID)
	cp ../edk2/ShellBinPkg/UefiShell/X64/Shell.efi mnt/
	echo setenv bootargs > efi_shell.txt
	echo scsi scan >> efi_shell.txt
	echo load scsi 0:1 \$${loadaddr} Shell.efi >> efi_shell.txt
	echo bootefi \$${loadaddr} >> efi_shell.txt
	mkimage -T script -n 'run EFI shell' -d efi_shell.txt mnt/boot.scr
	cp startup.nsh mnt/
	test -f UEFI2.6SCTII_Final_Release.zip || \
	wget http://www.uefi.org/sites/default/files/resources/UEFI2.6SCTII_Final_Release.zip
	rm -rf sct.tmp
	mkdir sct.tmp
	unzip UEFI2.6SCTII_Final_Release.zip -d sct.tmp
	cd sct.tmp && unzip UEFISCT.zip
	cp sct.tmp/UEFISCT/SctPackageX64/X64/* mnt -R
	cd sct.tmp && unzip IHVSCT.zip
	cp sct.tmp/IHVSCT/SctPackageX64/X64/* mnt -R
	rm -rf sct.tmp
	rm -f sct-amd64.img
	sudo umount mnt || true
	dd if=/dev/zero of=sct-amd64.img bs=1024 count=1 seek=1023
	cat sct-amd64.part1 >> sct-amd64.img
	rm sct-amd64.part1 efi_shell.txt
	echo -e "image1: start= 2048, type=ef\n" | \
	/sbin/sfdisk sct-amd64.img

sct:
	test -f sct-amd64.img || \
	make sct-prepare
	qemu-system-x86_64 $(KVM) -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-drive if=none,file=sct-amd64.img,id=mydisk,format=raw \
	-device ich9-ahci,id=ahci \
	-device ide-drive,drive=mydisk,bus=ahci.0

check:
	qemu-system-x86_64 $(KVM) -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0
check-s:
	qemu-system-x86_64 $(KVM) -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 -S \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0

clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:

uninstall:
