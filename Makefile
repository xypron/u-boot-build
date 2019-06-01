# Build U-Boot for x86
.POSIX:

TAG=2019.07
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
	export KVM=-enable-kvm
	undefine CROSS_COMPILE
else ifeq ("i686", $(MK_ARCH))
	export KVM=-enable-kvm
	undefine CROSS_COMPILE
else
	undefine KVM
	export CROSS_COMPILE=/usr/bin/x86_64-linux-gnu-
endif
undefine MK_ARCH

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
	test -d ipxe || git clone -v \
	http://git.ipxe.org/ipxe.git ipxe
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )
	test -d tftp || mkdir tftp

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
	cp config/chain.ipxe ipxe/src/config/local/
	cd ipxe/src && make bin-i386-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe
	cp ipxe/src/bin-i386-efi/snp.efi tftp/snp-i386.efi

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f tftp/snp-i386.efi || make build-ipxe
	cd denx && (git fetch origin || true)
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	cd denx && git checkout master && git rebase
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout origin/master -b pre-build
	cd denx && ( git branch -D build || true )
	cd denx && git checkout -b build
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

unit-tests:
	# cd denx && test/py/test.py --bd qemu-x86 -k test_efi_dhcp
	# cd denx && test/py/test.py --bd qemu-x86 -k test_efi_helloworld_net
	cd denx && test/py/test.py --build-dir . --bd qemu-x86 -k test_efi_loader

sct-prepare:
	mkdir -p mnt
	sudo umount mnt || true
	rm -f sct-i386.part1
	/sbin/mkfs.vfat -C sct-i386.part1 1047552
	sudo mount sct-i386.part1 mnt -o uid=$(UID)
	cp ../edk2/ShellBinPkg/UefiShell/Ia32/Shell.efi mnt/
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
	cp sct.tmp/UEFISCT/SctPackageIA32/IA32/* mnt -R
	cd sct.tmp && unzip IHVSCT.zip
	cp sct.tmp/IHVSCT/SctPackageIA32/IA32/* mnt -R
	rm -rf sct.tmp
	rm -f sct-i386.img
	sudo umount mnt || true
	dd if=/dev/zero of=sct-i386.img bs=1024 count=1 seek=1023
	cat sct-i386.part1 >> sct-i386.img
	rm sct-i386.part1 efi_shell.txt
	echo -e "image1: start= 2048, type=ef\n" | \
	/sbin/sfdisk sct-i386.img

sct:
	test -f sct-i386.img || \
	make sct-prepare
	qemu-system-i386 -bios denx/u-boot.rom -nographic -gdb tcp::1234 \
	$(KVM) -netdev \
	user,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 -machine pc-i440fx-2.5 \
	-drive if=none,file=sct-i386.img,id=mydisk,format=raw \
	-device ich9-ahci,id=ahci \
	-device ide-drive,drive=mydisk,bus=ahci.0

check:
	qemu-system-i386 -bios denx/u-boot.rom -nographic -gdb tcp::1234 \
	$(KVM) -netdev \
	user,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 -machine pc-i440fx-2.5 \
	-drive if=none,file=sct-i386.img,id=mydisk,format=raw \
	-device ich9-ahci,id=ahci \
	-device ide-drive,drive=mydisk,bus=ahci.0 || \
	qemu-system-i386 -bios denx/u-boot.rom -nographic -gdb tcp::1234 \
	-netdev \
	user,id=eth0,tftp=tftp \
	-device e1000,netdev=eth0 -machine pc-i440fx-2.5

clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:

uninstall:
