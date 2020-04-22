# Build U-Boot for QEMU arm64
.POSIX:

TAG=2020.07
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
	make build

prepare:
	test -d patch/.git || \
	git submodule init patch && git submodule update patch
	test -d denx || git clone -v \
	https://gitlab.denx.de/u-boot/u-boot.git denx
	cd denx && (git fetch origin --prune || true)
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
	cd ipxe/src && make bin-arm64-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/chain.ipxe

build:
	cd patch && (git fetch origin || true)
	cd patch && (git am --abort || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f ipxe/src/bin-arm64-efi/snp.efi || make build-ipxe
	cp ipxe/src/bin-arm64-efi/snp.efi tftp/snp-arm64.efi
	cd denx && (git fetch origin --prune || true)
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
	rm -f sct-arm64.part1
	/sbin/mkfs.vfat -F 32 -C sct-arm64.part1 131071
	sudo mount sct-arm64.part1 mnt -o uid=$(UID)
	echo scsi scan > efi_shell.txt
	echo load scsi 0:1 \$${kernel_addr_r} Shell.efi >> efi_shell.txt
	echo bootefi \$${kernel_addr_r} >> efi_shell.txt
	mkimage -T script -n 'run EFI shell' -d efi_shell.txt mnt/boot.scr
	cp startup.nsh mnt/
	touch mnt/run
	rsync -avP \
	../edk2-build/edk2/Build/UefiSct/RELEASE_GCC5/SctPackageAARCH64/AARCH64/. \
	mnt/ || true
	cp ../edk2-build/edk2/Build/Shell/RELEASE_GCC5/AARCH64/Shell.efi mnt/
	mkdir -p mnt/Sequence/
	cp config/*.seq mnt/Sequence/
	rm -f sct-arm64.img
	sudo umount mnt || true
	dd if=/dev/zero of=sct-arm64.img bs=1024 count=1 seek=1023
	cat sct-arm64.part1 >> sct-arm64.img
	rm sct-arm64.part1 efi_shell.txt
	echo -e "image1: start=2048, type=ef\n" | \
	/sbin/sfdisk sct-arm64.img

sct:
	test -f sct-arm64.img || \
	make sct-prepare
	qemu-system-aarch64 $(KVM) -machine virt -m 1G \
	-bios denx/u-boot.bin -nographic \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-device virtio-rng-pci \
	-drive if=none,file=sct-arm64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0
	mkdir -p sct-results

sct-get-results:
	sudo umount mnt || true
	sudo mount sct-arm64.img mnt -o offset=1048576,ro
	mkdir -p sct-results
	cp mnt/Results/*.csv sct-results
	sudo umount mnt

check:
	test -f arm64.img || \
	qemu-system-aarch64 -machine virt -m 1G -smp cores=2 \
	-bios denx/u-boot.bin $(KVM) -nographic -gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-device virtio-rng-pci
	test ! -f arm64.img || \
	qemu-system-aarch64 -machine virt -m 1G -smp cores=2 \
	-bios denx/u-boot.bin $(KVM) -nographic -gdb tcp::1234 \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-drive if=none,file=arm64.img,format=raw,id=mydisk \
	-device virtio-rng-pci \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0

check-el3:
	test -f arm64.img || \
	qemu-system-aarch64 -machine virt,secure=true,virtualization=true \
	-cpu cortex-a53 -m 1G -bios denx/u-boot.bin -nographic \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0
	test ! -f arm64.img || \
	qemu-system-aarch64 -machine virt,secure=true,virtualization=true \
	-cpu cortex-a53 -m 1G -bios denx/u-boot.bin -nographic \
	-netdev user,id=eth0,tftp=tftp -device e1000,netdev=eth0 \
	-drive if=none,file=arm64.img,format=raw,id=mydisk \
	-device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0

clean:
	test ! -d denx || ( cd denx && make clean )

install:

uninstall:
