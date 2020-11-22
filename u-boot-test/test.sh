#!/bin/sh
export PATH=$(pwd):/usr/bin:/bin
export PYTHONPATH=$(pwd)
# cd ../denx && ./test/py/test.py --bd=sandbox -ra --build-dir=.
cd ../denx && ./test/py/test.py --bd=sandbox -ra --build-dir=. -k=test_fs
