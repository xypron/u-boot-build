#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
cd ../denx && ./test/py/test.py --bd=qemu-arm64 -ra --build-dir=. -k=test_efi_
#cd ../denx && ./test/py/test.py --bd=qemu-arm64 -ra --build-dir=.
