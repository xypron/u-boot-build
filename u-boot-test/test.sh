#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
sd-mux-ctrl -v 0 -td
cd ../denx && ./test/py/test.py --bd=pine64-lts --build-dir=.
