# Build U-Boot for x86
.POSIX:

TAG=2018.05
TAGPREFIX=v
REVISION=001

NPROC=${shell nproc}

PATH:=$(PATH):$(CURDIR)/u-boot-test
export PATH

PYTHONPATH:=$(CURDIR)/u-boot-test
export PYTHONPATH

export LOCALVERSION:=-P$(REVISION)
export BUILD_ROM=y

all:
	which gmake && gmake prepare || make prepare
	which gmake && gmake build || make build

prepare:
	test -d patch || git submodule init && git submodule update
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
	mkdir -p ipxe/src/config/local/
	cp config/*.h ipxe/src/config/local/
	cp config/boot.ipxe ipxe/src/config/local/
	cd ipxe/src && make bin-i386-efi/snp.efi -j$(NPROC) \
	EMBED=config/local/boot.ipxe
	cp ipxe/src/bin-i386-efi/snp.efi tftp

build:
	cd patch && (git fetch origin || true)
	cd patch && (git checkout efi-next)
	cd patch && (git rebase)
	test -f tftp/snp.efi || make build-ipxe
	cd denx && (git fetch origin || true)
	cd denx && (git fetch agraf || true)
	# cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	# grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && (git am --abort || true)
	cd denx && git reset --hard
	# cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && git checkout master
	cd denx && ( git branch -D pre-build || true )
	cd denx && git checkout agraf/efi-next -b pre-build
	cd denx && git rebase origin/master
	# cd denx && git checkout efi-next
	# cd denx && git checkout master
	# cd denx && git reset --hard HEAD~30
	# cd denx && git rebase
	# cd denx && git rebase origin/master
	cd denx && ( git branch -D build || true )
	cd denx && ( git am --abort || true )
	cd denx && git checkout -b build
	# cd denx && ../patch/patch-$(TAG)
	cd denx && ../patch/patch-efi-next.sh
	cd denx && make mrproper
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j$(NPROC)

unit-tests:
	# cd denx && test/py/test.py --bd qemu-x86 -k test_efi_dhcp
	# cd denx && test/py/test.py --bd qemu-x86 -k test_efi_helloworld_net
	cd denx && test/py/test.py --build-dir . --bd qemu-x86 -k test_efi_loader

iso:
	qemu-system-x86_64 -m 1G \
	-net nic,vlan=0,macaddr=12:A1:00:12:34:02 \
	-net tap,vlan=0,ifname=tap0,script=no,downscript=no \
	-machine pc-i440fx-2.8 -drive file=ipxe.iso,if=ide,format=raw,media=cdrom

liv:
	qemu-system-x86_64 -m 1G -bios denx/u-boot.rom \
	-display sdl -vga cirrus -gdb tcp::1234 \
	-net nic,vlan=0,macaddr=12:A1:00:12:34:02 \
	-net tap,vlan=0,ifname=tap0,script=no,downscript=no \
	-machine pc-i440fx-2.8 -drive file=img,if=ide,format=raw

lav:
	qemu-system-i386 -m 1G -bios denx/u-boot.rom -nographic \
	-gdb tcp::1234 \
	-net nic,vlan=0,macaddr=12:A1:00:12:34:02 \
	-net tap,vlan=0,ifname=tap0,script=no,downscript=no \
	-machine pc-i440fx-2.8 -drive file=img,if=ide,format=raw

sdl:
	qemu-system-i386 -m 1G -bios denx/u-boot.rom -display sdl -vga cirrus \
	-netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0,mac=12:A1:00:12:34:13 -machine pc-i440fx-2.8 -hda img

luv:
	qemu-system-i386 -m 1G -bios denx/u-boot.rom -nographic \
	-netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0,mac=12:A1:00:12:34:13 -machine pc-i440fx-2.8 \
	-hda img | tee -a log

sata:	
	qemu-system-x86_64 -m 1G -bios denx/u-boot.rom -nographic \
	-netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0,mac=12:A1:00:12:34:13 -machine pc-i440fx-2.8 \
	-hda img \
	-drive file=img.gps,if=none,id=Disk2 \
	-device ich9-ahci,id=ahcj \
	-device ide-drive,drive=Disk2,bus=ahcj.0 \
	-drive file=img.gpt,if=none,id=Disk1 \
	-device ich9-ahci,id=ahci \
	-device ide-drive,drive=Disk1,bus=ahci.0

check:
	qemu-system-x86_64 -bios denx/u-boot.rom -nographic -gdb tcp::1234 \
	-netdev \
	user,id=eth0,tftp=tftp,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
	-device e1000,netdev=eth0 -machine pc-i440fx-2.5

clean:
	cd denx && make distclean
	rm tftp/snp.efi

install:

uninstall:
