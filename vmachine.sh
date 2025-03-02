#!/usr/bin/env bash
# Script to run a headless virtual machine to do the tests

# Paths
TEST_ENV_DIR=$PWD/test_environment
VDA=$TEST_ENV_DIR/arch.qcow2
ISO=$TEST_ENV_DIR/arch.iso
UEFI_FIRMWARE_FILE=/usr/share/ovmf/x64/OVMF.4m.fd
BIOS_FIRMWARE_FILE=/usr/share/qemu/bios-256k.bin

# Machine specs
CORES=2
MEM="2G"
BOOT_TYPE="d" 
VDA_SIZE=40G
FIRMWARE_FILE=$BIOS_FIRMWARE_FILE  # BIOS is set as the default boot mode

usage() {
  printf "usage: $0 [-r] [-b boot_type] [-e|-m] [-h]\n"
  printf "\t-r\t\t Delete the virtual disk and recreate it.\n"
  printf "\t-b boot_type\t Set boot type ('d' for CD, 'c' for disk) Default is 'd'.\n"
  printf "\t-e\t\t Set the boot mode to UEFI.\n"
  printf "\t-m\t\t Set the boot mode to BIOS.\n"
  printf "\t-h\t\t Display this help message.\n"
  exit 0
}

validate_boot_type() {
  if [[ ! "$1" =~ ^(d|c)$ ]]; then
    echo "error: invalid boot type '$1'. valid options are 'd' (cdrom) or 'c' (disk)."
    exit 1
  fi
}

reset_vm() {
    if pid=$(pidof qemu-system-x86_64); then
        kill $pid >/dev/null 2>&1
        sleep 1
    fi
    [ -f $VDA ] && rm -f $VDA
}

main() {
    # Process args
    while getopts "rmeb:h" opt; do
        case $opt in
            r)
                reset_vm
                ;;
            b)
                BOOT_TYPE=$OPTARG
                validate_boot_type $BOOT_TYPE
                ;;
            e)
                FIRMWARE_FILE=$UEFI_FIRMWARE_FILE
                ;;
            m)
                FIRMWARE_FILE=$BIOS_FIRMWARE_FILE
                ;;
            h)
                usage
                ;;
            *)
                usage
                ;;
        esac
    done

    # Create disk if doesn't exist
    [ ! -f $VDA ] && qemu-img create -f qcow $VDA $VDA_SIZE >/dev/null

    # Run the virtual machine
    qemu-system-x86_64 \
        -m $MEM -smp $CORES -enable-kvm -cpu host -boot $BOOT_TYPE \
        -cdrom $ISO -hda $VDA -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device e1000,netdev=net0 \
        -bios $FIRMWARE_FILE \
        -spice port=5900,addr=127.0.0.1,disable-ticketing=on -device qxl & disown

    QEMU_PID=$!

    printf "info: virtual machine is running with process id: '$QEMU_PID'\n"
}

main "$@"
