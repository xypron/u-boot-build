#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
relay-card off
sd-mux-ctrl -v 0 -d
#  cd ../denx && ./test/py/test.py -ra --bd=orangepi_pc --build-dir=. -k=test_efi_
cd ../denx && ./test/py/test.py -ra --bd=orangepi_pc --build-dir=.
