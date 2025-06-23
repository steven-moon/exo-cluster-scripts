#!/bin/bash

# Automated exo installation script for macOS
# This script automatically handles Python setup and exo installation as a system service.

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Configuration
EXO_INSTALL_DIR="/opt/exo"
LAUNCH_AGENTS_DIR="/Library/LaunchDaemons"
PLIST_FILE="com.exolabs.exo.plist"
STARTUP_SCRIPT="start_exo.sh"
EXO_REPO_URL="https://github.com/exo-explore/exo.git"
VENV_DIR="$EXO_INSTALL_DIR/venv"
PYTHON_CMD=""
PYTHON_VERSION=""

# --- Pre-flight Checks ---

# Check if NOT running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root (use sudo)."
        print_error "The script will prompt for sudo access when required."
        exit 1
    fi
}

# Ask for sudo password upfront to avoid multiple prompts
ask_for_sudo() {
    print_status "This script requires sudo access to install system-wide services."
    if sudo -v; then
        # Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
        while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
        print_status "Sudo access granted."
    else
        print_error "Sudo access denied. Please run the script again."
        exit 1
    fi
}

# --- Python Environment Setup ---

check_python_prerequisites() {
    print_header "Step 1: Checking Python Prerequisites"
    
    if python_cmd=$(find_compatible_python); then
        PYTHON_CMD="$python_cmd"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
        print_status "Found compatible Python: $PYTHON_CMD (version $PYTHON_VERSION)"
    else
        print_warning "No compatible Python version (3.10+) found."
        read -p "Do you want to attempt to install Python 3.12 via Homebrew? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if install_python_homebrew; then
                if python_cmd=$(find_compatible_python); then
                    PYTHON_CMD="$python_cmd"
                    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
                    print_status "Python installation successful: $PYTHON_CMD (version $PYTHON_VERSION)"
                else
                    print_error "Failed to find Python after installation. Please install Python 3.10+ manually."
                    exit 1
                fi
            else
                print_error "Failed to install Python automatically. Please install Python 3.10+ manually."
                exit 1
            fi
        else
            print_error "Python 3.10+ is required to proceed. Aborting installation."
            exit 1
        fi
    fi

    if ! "$PYTHON_CMD" -m venv --help > /dev/null 2>&1; then
        print_error "Python virtual environment support ('venv') is not available."
        print_error "Please install the 'python3-venv' package or use a different Python installation."
        exit 1
    fi
    print_status "Python prerequisites check passed."
}

# --- Installation Steps ---

create_directories() {
    print_header "Step 2: Creating Directories"
    print_status "Creating installation and log directories with sudo..."
    sudo mkdir -p "$EXO_INSTALL_DIR/scripts"
    sudo mkdir -p /var/log/exo
    sudo touch /var/log/exo/exo.log
    sudo chown -R "$(whoami)":admin "$EXO_INSTALL_DIR"
    sudo chown root:wheel /var/log/exo
    sudo chmod 775 /var/log/exo
}

setup_exo_repository() {
    print_header "Step 3: Setting up exo Repository"
    if [ -d "$EXO_INSTALL_DIR/.git" ]; then
        print_status "exo repository already exists, updating..."
        cd "$EXO_INSTALL_DIR"
        git fetch origin
        git reset --hard origin/main
    else
        print_status "Cloning exo repository from GitHub..."
        git clone "$EXO_REPO_URL" "$EXO_INSTALL_DIR"
    fi
    cd "$EXO_INSTALL_DIR"
    print_status "Repository setup complete."
}

setup_virtual_environment() {
    print_header "Step 4: Setting up Python Virtual Environment"
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating Python virtual environment using $PYTHON_CMD..."
        "$PYTHON_CMD" -m venv "$VENV_DIR"
    else
        print_status "Virtual environment already exists. Re-installing dependencies."
    fi
    
    source "$VENV_DIR/bin/activate"
    
    print_status "Upgrading pip and installing 'exo'..."
    pip install --quiet --upgrade pip
    
    if ! pip install --quiet -e .; then
        print_error "Failed to install 'exo'. Please check the output for errors."
        deactivate
        exit 1
    fi
    
    deactivate
    print_status "Virtual environment setup complete."
}

install_service() {
    print_header "Step 5: Installing System Service"
    print_status "Installing launch daemon and helper scripts..."
    
    # Copy scripts from the cloned project repo, not the installer repo
    local installer_scripts_dir="$SCRIPT_DIR/scripts"
    local service_scripts_dir="$EXO_INSTALL_DIR/scripts"
    
    sudo cp "$installer_scripts_dir/$STARTUP_SCRIPT" "$service_scripts_dir/"
    sudo cp "$installer_scripts_dir/check_exo_status.sh" "$service_scripts_dir/"
    sudo cp "$installer_scripts_dir/uninstall_exo_service.sh" "$service_scripts_dir/"
    sudo cp "$installer_scripts_dir/exo_config_example.sh" "$service_scripts_dir/"
    sudo cp "$installer_scripts_dir/$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"
    
    print_status "Creating system-wide symlinks for 'exo' and 'exo-status'..."
    sudo ln -sf "$VENV_DIR/bin/exo" "/usr/local/bin/exo"
    sudo ln -sf "$service_scripts_dir/check_exo_status.sh" "/usr/local/bin/exo-status"
    
    print_status "Setting permissions and loading service..."
    sudo chmod +x "$service_scripts_dir"/*.sh
    sudo chown -R root:wheel "$EXO_INSTALL_DIR"
    sudo chmod -R 755 "$EXO_INSTALL_DIR"
    sudo chown root:wheel "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
    sudo chmod 644 "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
    
    # Unload existing service if it's running, then load the new one
    sudo launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null || true
    sudo launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
}

verify_installation() {
    print_header "Step 6: Verifying Installation"
    local success=true
    
    if ! sudo launchctl list | grep -q "com.exolabs.exo"; then
        print_error "Service 'com.exolabs.exo' not loaded."
        success=false
    else
        print_status "Service 'com.exolabs.exo' is loaded."
    fi
    
    if ! command -v exo-status &>/dev/null; then
        print_error "'exo-status' command not found in PATH."
        success=false
    else
        print_status "'exo-status' command is available."
    fi
    
    if $success; then
        print_header "Installation completed successfully!"
        echo ""
        print_status "exo is now installed and running as a system service."
        print_status "To check the status, run: exo-status"
        print_status "To view logs, run: tail -f /var/log/exo/exo.log"
        print_status "The web interface should be available at: http://localhost:52415"
        echo ""
        print_status "To uninstall, run: sudo /opt/exo/scripts/uninstall_exo_service.sh"
    else
        print_error "Installation verification failed. Please check the logs."
        exit 1
    fi
}

# --- Main Function ---

main() {
    print_header "Automated exo Installation for macOS"
    
    check_not_root
    ask_for_sudo
    
    check_python_prerequisites
    create_directories
    setup_exo_repository
    setup_virtual_environment
    install_service
    verify_installation
}

main "$@" 