# Build U-Boot for StarFive VisionFive 2
.POSIX:

export TTYDEVICE="/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.2:1.0-port0"

all:

flash:
	relay-card off
	sd-mux-ctrl -e xypron-0002 -td
	sd-mux-ctrl -e xypron-0002 -ts
	sleep 3
	dd conv=fsync,notrunc if=denx/u-boot.itb \
	of=/dev/sda2 bs=1M
	dd conv=fsync,notrunc if=denx/spl/u-boot-spl.bin.normal.out \
	of=/dev/sda13 bs=1M
	sleep 1
	sd-mux-ctrl -e xypron-0002 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200

run:
	sd-mux-ctrl -e xypron-0002 -td
	relay-card on
	picocom $(TTYDEVICE) --baud 115200
