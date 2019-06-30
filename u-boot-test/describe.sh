#!/bin/bash
echo env__efi_loader_$(basename $1 | sed 's/\./_/g') = \{
echo '    "fn":' \"$(basename $1)\",
echo '    "size":' $(stat --printf="%s" $1),
echo '    "crc32":' \"$(crc32 $1)\",
echo \}
