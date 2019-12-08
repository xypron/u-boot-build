FS0:
cls
if exist run then
  rm run
  SCT -s uboot.seq
else
  SCT -c
endif
