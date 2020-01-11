FS0:
cls
if exist run then
  rm run
  SCT -s uboot.seq
else
  SCT -c
endif
SCT -g result.csv
echo run > run
SCT -r
echo Test results are in Report\result.csv
echo DONE - SCT COMPLETED
