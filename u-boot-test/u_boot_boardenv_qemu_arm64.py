env__net_dhcp_server = True

env__net_static_env_vars = [
    ('ipaddr', '10.0.2.15'),
    ('netmask', '255.255.255.0'),
    ('serverip', '10.0.2.2'),
]

env__net_tftp_readable_file = {
    "fn": "helloworld.efi",
    "size": 4480,
    "crc32": "19f9c0ab",
    "addr": 0x40400000,
}

env__efi_loader_grub_file = {
    "fn": "grubaa64.efi",
    "size": 729088,
    "crc32": "db781685",
}

env__efi_loader_helloworld_file = {
    "fn": "helloworld.efi",
    "size": 4480,
    "crc32": "19f9c0ab",
    "addr": 0x40400000,
}

env__efi_fit_tftp_file = {
    "fn": "test-efi-fit.img",
    "addr": 0x40400000,
    "dn": "../tftp/",
}
