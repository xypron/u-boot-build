#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
cd ../denx && ./test/py/test.py --bd=qemu-system-riscv32 --build-dir=. -k=test_efi_
# cd ../denx && python3 ./test/py/test.py --bd=qemu-system-riscv32 --build-dir=.
