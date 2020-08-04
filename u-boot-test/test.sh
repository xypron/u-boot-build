#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
#cd ../denx && ./test/py/test.py --bd=sipeed_maix_bitm -ra --build-dir=. -k=test_efi_
cd ../denx && ./test/py/test.py --bd=sipeed_maix_bitm -ra --build-dir=.
