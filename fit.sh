#!/bin/sh
# Generate a FIT image for testing

set -e

cd denx/

cat > test-efi-fit-helloworld.its << EOF
/dts-v1/;

/ {
    description = "EFI image with FDT blob";
    #address-cells = <1>;

    images {
        efi {
            description = "Test EFI";
            data = /incbin/("test-efi-fit-helloworld.efi");
            type = "kernel_noload";
            arch = "riscv";
            os = "efi";
            compression = "none";
            load = <0x0>;
            entry = <0x0>;
        };
        fdt {
            description = "Test FDT";
            data = /incbin/("test-efi-fit-user.dtb");
            type = "flat_dt";
            arch = "riscv";
            compression = "none";
        };
    };

    configurations {
        default = "config-efi-fdt";
        config-efi-fdt {
            description = "EFI FIT w/ FDT";
            kernel = "efi";
            fdt = "fdt";
        };
        config-efi-nofdt {
            description = "EFI FIT w/o FDT";
            kernel = "efi";
        };
    };
};
EOF

cat > test-efi-fit-user.dts << EOF
/dts-v1/;

/ {
    #address-cells = <1>;
    #size-cells = <0>;

    model = "riscv users EFI FIT Boot Test";
    compatible = "riscv";

    reset@0 {
        compatible = "riscv,reset";
        reg = <0>;
    };
};
EOF

cp lib/efi_loader/helloworld.efi test-efi-fit-helloworld.efi
dtc -I dts -O dtb -o test-efi-fit-user.dtb test-efi-fit-user.dts
mkdir -p ../tftp
tools/mkimage -f test-efi-fit-helloworld.its ../tftp/riscv64.fit
rm test-efi-fit-*
