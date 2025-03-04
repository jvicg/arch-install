#!/usr/bin/env bash
# Installation of all the dependencies

trap ctrl_c SIGINT SIGTERM  

TMP_DIR="/tmp"
TMP_DIR_SIZE="1G"
INSTALLATION_DIR="$TMP_DIR/arch-install"
VENV_DIR="$INSTALLATION_DIR/.venv"
REQUIREMENTS_FILE="$INSTALLATION_DIR/requirements.txt"
REPO_URL="https://github.com/jvicg/arch-install"
TEST_URL="github.com"
MIN_GB_RAM=2

ctrl_c() {
    # Exit the script and rollback the installation if user interrupts the execution
    echo "warning: The execution was interrupted. Cleaning up..."
    cleanup
}

cleanup() {
    # Remove the installation directory
    if [ -d "$INSTALLATION_DIR" ]; then
        rm -rf "$INSTALLATION_DIR"
    fi

    exit 1
}

check_ram() {
    # Check if the system has at least 2GB of RAM
    local ram=$(free -m | awk '/^Mem:/ {print int($2 / 1024)}')
    if [ $ram -lt $MIN_GB_RAM ]; then
        echo "error: The system must have at least ${MIN_GB_RAM}GB of RAM. The current system has ${ram}GB of RAM."
        exit 1
    fi
}

check_network() {
    # Check if the system has network connection
    if ! ping -c2 $TEST_URL &> /dev/null; then
        echo "error: No network connection. Please check that you have access to the Internet."
        exit 1
    fi
}

check_if_installed() {
    trap - SIGINT SIGTERM

    # Check if script was already executed
    if [ -d "$INSTALLATION_DIR" ]; then
        while true; do
            read -r -p "warning: The script was already executed. Do you want to reinstall? [y/N]: " choice
            choice=${choice:-N}  # Default value is No

            case "$choice" in
                [yY]) 
                    echo "info: Reinstalling..."
                    rm -rf "$INSTALLATION_DIR"
                    break  # Sale del bucle y continúa con la instalación
                    ;;
                [nN]) 
                    echo "error: Process aborted."
                    exit 1
                    ;;
                *) 
                    echo "warning: Invalid input. Please enter 'y' for Yes or 'n' for No."
                    ;;
            esac
        done
    fi

    trap ctrl_c SIGINT SIGTERM 
}

main() {

    # Prechecks 
    check_network
    check_if_installed
    check_ram 

    # Extends the size of tmpfs to ensure it has enough space to clone the repository and install Ansible
    mount -o remount,size=${TMP_DIR_SIZE} ${TMP_DIR} 

    if [ $? -ne 0 ]; then
        echo "error: There was an error extending the size of tmpfs."
        exit 1
    fi

    # Install git and clone the repository
    pacman -Sy git --noconfirm >/dev/null 2>&1 # Install git
    git clone --depth 1 --branch main --single-branch $REPO_URL $INSTALLATION_DIR

    # Create and install dependencies 
    python3 -m venv $VENV_DIR
    source $VENV_DIR/bin/activate
    
    # Install the dependencies
    pip install -r $REQUIREMENTS_FILE

    if [ $? -ne 0 ]; then
        echo "error: There was an error installing the dependencies."
        cleanup
    fi

    ansible-galaxy collection install community.general ansible.posix

    echo "info: Installation completed successfully."
    exit 0
}

main
