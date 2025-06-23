#!/bin/bash

# Automated exo installation script for macOS
# This script automatically handles Python setup and exo installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[AUTO-INSTALL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AUTO-INSTALL]${NC} $1"
}

print_error() {
    echo -e "${RED}[AUTO-INSTALL]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[AUTO-INSTALL]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Do not run this script as root (without sudo)"
    print_error "The script will prompt for sudo when needed"
    exit 1
fi

print_header "Automated exo Installation for macOS"
print_status "This script will automatically:"
print_status "1. Set up the correct Python environment"
print_status "2. Install Python via Homebrew if needed"
print_status "3. Install exo as a system service"
echo ""

# Step 1: Setup Python environment
print_header "Step 1: Setting up Python environment..."
if ! ./scripts/setup_python_env.sh; then
    print_error "Failed to set up Python environment"
    exit 1
fi

# Step 2: Source the Python environment
print_header "Step 2: Loading Python environment..."
if [[ -f "/tmp/exo_python_env" ]]; then
    source /tmp/exo_python_env
    print_status "Python environment loaded:"
    print_status "  Command: $EXO_PYTHON_CMD"
    print_status "  Version: $EXO_PYTHON_VERSION"
    print_status "  Path: $EXO_PYTHON_PATH"
else
    print_error "Python environment file not found"
    exit 1
fi

# Step 3: Run the installation
print_header "Step 3: Installing exo service..."
print_status "Running installation with configured Python environment..."

if sudo -E ./scripts/install_exo_service.sh; then
    print_header "Installation completed successfully!"
    echo ""
    print_status "exo is now installed and running as a system service"
    print_status "Web interface: http://localhost:52415"
    print_status "API endpoint: http://localhost:52415/v1/chat/completions"
    echo ""
    print_status "To check status: exo-status"
    print_status "To view logs: tail -f /var/log/exo/exo.log"
    print_status "To manage service:"
    echo "  sudo launchctl start com.exolabs.exo"
    echo "  sudo launchctl stop com.exolabs.exo"
    echo ""
    print_status "To uninstall: sudo ./scripts/uninstall_exo_service.sh"
else
    print_error "Installation failed"
    print_error "Check the error messages above for details"
    exit 1
fi

# Cleanup
rm -f /tmp/exo_python_env 