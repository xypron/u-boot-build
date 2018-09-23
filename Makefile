# Build U-Boot for QEMU arm
.POSIX:

TAG=2018.09
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
	cp ipxe/src/bin-arm32-efi/snp.efi tftp
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

sct-prepare:
	mkdir -p mnt
	sudo umount mnt || true
	rm -f sct-arm.part1
	/sbin/mkfs.vfat -C sct-arm.part1 131071
	sudo mount sct-arm.part1 mnt -o uid=$(UID)
	cp ../edk2/ShellBinPkg/MinUefiShell/Arm/Shell.efi mnt/
	echo scsi scan > efi_shell.txt
	echo load scsi 0:1 \$${kernel_addr_r} Shell.efi >> efi_shell.txt
	echo bootefi \$${kernel_addr_r} \$${fdtcontroladdr} >> efi_shell.txt
	mkimage -T script -n 'run EFI shell' -d efi_shell.txt mnt/boot.scr
	cp startup.nsh mnt/
	test -f UEFI2.6SCTII_Final_Release.zip || \
	wget http://www.uefi.org/sites/default/files/resources/UEFI2.6SCTII_Final_Release.zip
	rm -rf sct.tmp
	mkdir sct.tmp
	unzip UEFI2.6SCTII_Final_Release.zip -d sct.tmp
	cd sct.tmp && unzip UEFISCT.zip
	cp sct.tmp/UEFISCT/SctPackageARM/ARM/* mnt -R
	cd sct.tmp && unzip IHVSCT.zip
	cp sct.tmp/IHVSCT/SctPackageARM/ARM/* mnt -R
	rm -rf sct.tmp
	rm -f sct-arm.img
	sudo umount mnt || true
	dd if=/dev/zero of=sct-arm.img bs=1024 count=1 seek=1023
	cat sct-arm.part1 >> sct-arm.img
	rm sct-arm.part1 efi_shell.txt
	echo -e "image1: start= 2048, type=ef\n" | \
	/sbin/sfdisk sct-arm.img

sct:
	test -f sct-arm.img || \
	make sct-prepare
	qemu-system-arm -machine virt -cpu cortex-a15 \
	-bios denx/u-boot.bin -nographic -netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0 \
	-drive if=none,file=sct-arm.img,id=mydisk -device ich9-ahci,id=ahci \
	-device ide-drive,drive=mydisk,bus=ahci.0

check:
	qemu-system-arm -machine virt -cpu cortex-a15 \
	-bios denx/u-boot.bin -nographic -netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0

debug:
	qemu-system-arm -machine virt -cpu cortex-a15 \
	-bios denx/u-boot.bin -nographic -gdb tcp::1234 -netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
