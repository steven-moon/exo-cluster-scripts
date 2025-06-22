#!/bin/bash

# Installation script for exo startup service on macOS
# This script installs exo as a system-wide service that starts on boot

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Store the original script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
EXO_INSTALL_DIR="/opt/exo"
LAUNCH_AGENTS_DIR="/Library/LaunchDaemons"
PLIST_FILE="com.exolabs.exo.plist"
STARTUP_SCRIPT="start_exo.sh"
EXO_REPO_URL="https://github.com/exo-explore/exo.git"
VENV_DIR="$EXO_INSTALL_DIR/venv"

print_status "Installing exo startup service..."

# Function to check if exo is already installed and running
check_existing_installation() {
    if [ -d "$EXO_INSTALL_DIR" ]; then
        print_warning "exo installation directory already exists at $EXO_INSTALL_DIR"
        
        # Check if it's a git repository
        if [ -d "$EXO_INSTALL_DIR/.git" ]; then
            print_status "Found existing git repository"
        else
            print_warning "Directory exists but is not a git repository"
        fi
        
        # Check if virtual environment exists
        if [ -d "$VENV_DIR" ]; then
            print_status "Found existing virtual environment"
        else
            print_warning "No virtual environment found"
        fi
        
        # Check if service is already loaded
        if launchctl list | grep -q "com.exolabs.exo"; then
            print_warning "exo service is already loaded"
            read -p "Do you want to reinstall? This will stop the current service. (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Stopping existing service..."
                launchctl stop com.exolabs.exo 2>/dev/null || true
                launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null || true
            else
                print_status "Installation cancelled"
                exit 0
            fi
        else
            print_status "No existing service found, proceeding with installation"
        fi
    fi
}

# Function to create directories with proper permissions
create_directories() {
    print_status "Creating installation directory: $EXO_INSTALL_DIR"
    mkdir -p "$EXO_INSTALL_DIR"
    
    print_status "Creating startup scripts directory..."
    mkdir -p "$EXO_INSTALL_DIR/startup_scripts"
    
    print_status "Creating log directory..."
    mkdir -p /var/log/exo
    chown root:wheel /var/log/exo
    chmod 755 /var/log/exo
    
    print_status "Creating PID file..."
    mkdir -p /var/run
    touch /var/run/exo.pid
    chown root:wheel /var/run/exo.pid
    chmod 644 /var/run/exo.pid
}

# Function to clone or update exo repository
setup_exo_repository() {
    if [ -d "$EXO_INSTALL_DIR/.git" ]; then
        print_status "exo repository already exists, updating..."
        cd "$EXO_INSTALL_DIR"
        git fetch origin
        git reset --hard origin/main
    elif [ -d "$EXO_INSTALL_DIR" ]; then
        print_warning "Directory $EXO_INSTALL_DIR exists but is not a git repository"
        print_status "Removing existing directory and cloning fresh repository..."
        rm -rf "$EXO_INSTALL_DIR"
        git clone "$EXO_REPO_URL" "$EXO_INSTALL_DIR"
    else
        print_status "Cloning exo repository from GitHub..."
        git clone "$EXO_REPO_URL" "$EXO_INSTALL_DIR"
    fi
    
    cd "$EXO_INSTALL_DIR"
}

# Function to configure MLX
configure_mlx() {
    print_status "Configuring MLX for optimal performance on Apple Silicon..."
    if [ -f "configure_mlx.sh" ]; then
        chmod +x configure_mlx.sh
        ./configure_mlx.sh
    else
        print_warning "configure_mlx.sh not found, skipping MLX configuration"
    fi
    
    print_status "Updating MLX version to 0.26.1..."
    if [ -f "setup.py" ]; then
        # Backup original setup.py
        cp setup.py setup.py.backup
        
        # Update MLX version in setup.py
        sed -i '' 's/mlx==0.22.0/mlx==0.26.1/g' setup.py
        
        # Fix numpy version for Python 3.13 compatibility
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        if [[ "$python_version" == 3.13* ]]; then
            print_status "Updating numpy version for Python 3.13 compatibility..."
            sed -i '' 's/numpy==2.0.0/numpy<2.0.0/g' setup.py
        fi
        
        print_status "Updated MLX version in setup.py"
    else
        print_warning "setup.py not found, cannot update MLX version"
    fi
}

# Function to setup virtual environment
setup_virtual_environment() {
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
    else
        print_status "Virtual environment already exists"
    fi
    
    print_status "Installing exo in virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip in virtual environment
    pip install --upgrade pip
    
    # Fix numpy compatibility issue with Python 3.13
    python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
    if [[ "$python_version" == 3.13* ]]; then
        print_status "Detected Python 3.13, installing compatible numpy version..."
        pip install "numpy<2.0.0"
    fi
    
    # Install exo in development mode
    print_status "Installing exo using pip install -e ."
    pip install -e .
}

# Function to install startup scripts
install_startup_scripts() {
    print_status "Installing startup script..."
    mkdir -p "$EXO_INSTALL_DIR/startup_scripts"
    cp "$SCRIPT_DIR/$STARTUP_SCRIPT" "$EXO_INSTALL_DIR/startup_scripts/"
    chmod +x "$EXO_INSTALL_DIR/startup_scripts/$STARTUP_SCRIPT"
    
    print_status "Installing launch daemon configuration..."
    cp "$SCRIPT_DIR/$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"
    
    # Set proper permissions
    chown root:wheel "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
    chmod 644 "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
}

# Function to set permissions
set_permissions() {
    print_status "Setting proper permissions for exo installation..."
    chown -R root:wheel "$EXO_INSTALL_DIR"
    chmod -R 755 "$EXO_INSTALL_DIR"
}

# Function to load service
load_service() {
    print_status "Loading launch daemon..."
    launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check if exo executable exists
    if [ -x "$VENV_DIR/bin/exo" ]; then
        print_status "✓ exo executable found"
    else
        print_error "✗ exo executable not found"
        return 1
    fi
    
    # Check if startup script exists
    if [ -x "$EXO_INSTALL_DIR/startup_scripts/$STARTUP_SCRIPT" ]; then
        print_status "✓ Startup script installed"
    else
        print_error "✗ Startup script not found"
        return 1
    fi
    
    # Check if plist file exists
    if [ -f "$LAUNCH_AGENTS_DIR/$PLIST_FILE" ]; then
        print_status "✓ Launch daemon configuration installed"
    else
        print_error "✗ Launch daemon configuration not found"
        return 1
    fi
    
    # Check if service is loaded
    if launchctl list | grep -q "com.exolabs.exo"; then
        print_status "✓ Service loaded successfully"
    else
        print_error "✗ Service not loaded"
        return 1
    fi
    
    return 0
}

# Main installation process
main() {
    check_existing_installation
    create_directories
    setup_exo_repository
    configure_mlx
    setup_virtual_environment
    install_startup_scripts
    set_permissions
    load_service
    
    if verify_installation; then
        print_status "Installation completed successfully!"
        print_status "exo will now start automatically when the system boots"
        print_status ""
        print_status "Installation details:"
        print_status "  - exo repository: $EXO_REPO_URL"
        print_status "  - Installation directory: $EXO_INSTALL_DIR"
        print_status "  - Virtual environment: $VENV_DIR"
        print_status "  - MLX version: Updated to 0.26.1"
        print_status "  - Web interface: http://localhost:52415"
        print_status "  - API endpoint: http://localhost:52415/v1/chat/completions"
        print_status ""
        print_status "To manage the service:"
        print_status "  Start:   sudo launchctl start com.exolabs.exo"
        print_status "  Stop:    sudo launchctl stop com.exolabs.exo"
        print_status "  Status:  sudo launchctl list | grep exo"
        print_status "  Logs:    tail -f /var/log/exo/exo.log"
        print_status ""
        print_status "To uninstall:"
        print_status "  sudo ./startup_scripts/uninstall_exo_service.sh"
    else
        print_error "Installation verification failed. Please check the logs and try again."
        exit 1
    fi
}

# Run main installation
main 