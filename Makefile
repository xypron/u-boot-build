# Build U-Boot for QEMU arm
.POSIX:

TAG=2020.07
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

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

sct-prepare:
	mkdir -p mnt
	sudo umount mnt || true
	rm -f sct-arm32.part1
	/sbin/mkfs.vfat -C sct-arm32.part1 131071
	sudo mount sct-arm32.part1 mnt -o uid=$(UID)
	cp ../edk2/ShellBinPkg/UefiShell/Arm/Shell.efi mnt/
	echo scsi scan > efi_shell.txt
	echo load scsi 0:1 \$${kernel_addr_r} Shell.efi >> efi_shell.txt
	echo bootefi \$${kernel_addr_r} \$${fdtcontroladdr} >> efi_shell.txt
	mkimage -T script -n 'run EFI shell' -d efi_shell.txt mnt/boot.scr
	cp startup.nsh mnt/
	touch mnt/run
	rsync -avP \
	../edk2-build/edk2/Build/UefiSct/RELEASE_GCC5/SctPackageARM/ARM/. \
	mnt/ || true
	cp ../edk2-build/edk2/Build/Shell/RELEASE_GCC5/ARM/Shell.efi mnt/
	mkdir -p mnt/Sequence/
	cp config/uboot.seq mnt/Sequence/
	sudo umount mnt || true
	dd if=/dev/zero of=sct-arm32.img bs=1024 count=1 seek=1023
	cat sct-arm32.part1 >> sct-arm32.img
	rm sct-arm32.part1 efi_shell.txt
	echo -e "image1: start=2048, type=ef\n" | \
	/sbin/sfdisk sct-arm32.img

sct:
	test -f sct-arm32.img || \
	make sct-prepare
	qemu-system-arm -machine virt -cpu cortex-a15 -m 1G -smp cores=2 \
	-bios denx/u-boot.bin -nographic \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-drive if=none,file=sct-arm32.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0 \
	-device virtio-rng-pci

check:
	test -f arm32.img || \
	qemu-system-arm -machine virt -cpu cortex-a15 -m 1G -smp cores=2 \
	-bios denx/u-boot.bin -nographic \
	-device e1000,netdev=eth0 -netdev user,id=eth0,tftp=tftp \
	-gdb tcp::1234 -device virtio-rng-pci
	test ! -f arm32.img || \
	qemu-system-arm -machine virt -cpu cortex-a15 -m 1G -smp cores=2 \
	-bios denx/u-boot.bin -nographic \
	-device e1000,netdev=eth0 -netdev user,id=eth0,tftp=tftp \
	-gdb tcp::1234 -device virtio-rng-pci \
	-drive if=none,file=arm32.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
