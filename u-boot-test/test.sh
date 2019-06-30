#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
sd-mux-ctrl -v 0 -d
cd ../denx && ./test/py/test.py --bd=orangepi_pc --build-dir=. # -k=test_efi_
relay-card off
