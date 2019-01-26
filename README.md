Build scripts for U-Boot
========================

This project provides scripts to build and install U-Boot on a variety of
platforms. It is mainly used for development purposes.

Necessary patches are taken from https://github.com/xypron/u-boot-patches.

Branches
--------

For the different platforms branches have been created.

Where there a two branches for a platform the branch with '-dev' ending is used
to build against the current U-Boot efi-next branch while the other builds
against a release.

* bananapi - Banana Pi release
* bananapi-dev - Banana Pi development
* firefly-rk3399 - Firefly RK3399
* firefly-rk3399-rkloader - Firefly RK3399
* macchiatobin - MACCHIATObin
* macchiatobin-dev - MACCHIATObin development
* master - documentation only
* odroid-c2 - Odroid C2 release
* odroid-c2-dev - Odroid C2 development
* qemu-arm - QEMU target
* qemu-arm64 - QEMU target
* qemu-riscv64 - QEMU target
* qemu-x86 - QEMU target
* qemu-x86\_64 - QEMU target
* sandbox - testing target
* tinker - Asus Tinker Board release
* tinker-dev - Asus Tinker Board development
* vexpress\_ca15\_tc2-dev - QEMU target
* vexpress\_ca9x4 - QEMU target

Usage
-----

Checkout the relevant branch.

Install the U-Boot build dependencies:

```
sudo apt-get install bc bison build-essential coccinelle device-tree-compiler \
  dfu-util flex gdisk liblz4-tool libncurses5-dev libpython-dev libsdl1.2-dev \
  libssl-dev openssl python python-coverage python-pyelftools python-pytest \
  python3-sphinxcontrib.apidoc swig
```

Build with

```
make
```

Install to a directory with

```
make install DESTDIR=foo
```

Change to the installation directory and copy U-Boot to an SD card with

```
./sdimage /dev/sdX
```

Replace `/dev/sdX` by the correct device. Specifying the wrong device may
cause data loss on your computer. So be extra careful.

The different QEMU targets can be tested with

```
make check
```

License
-------

The scripts are published under the GPL v2 license. See file COPYING.
