#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
relay-card off
sd-mux-ctrl -v 0 -td
# cd ../denx && ./test/py/test.py -ra --bd=pine64-lts --build-dir=.
cd ../denx && ./test/py/test.py -ra --bd=pine64-lts --build-dir=. -k=test_efi_
