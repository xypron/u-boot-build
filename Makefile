all:

flash:
	switch off mars
	sd-mux-ctrl -v 0 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/spl/u-boot-spl.bin.normal.out \
	of=/dev/sda13 bs=1M
	dd conv=fsync,notrunc if=denx/u-boot.itb \
	of=/dev/sda2 bs=1M
	sleep 1
	sd-mux-ctrl -v 0 -td
	switch on mars
	mini mars

run:
	sd-mux-ctrl -v 0 -td
	switch on mars
	mini mars
