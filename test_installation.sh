#!/bin/bash

# Test script for exo installation and startup scripts
# This script tests the installation process and verifies functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Test configuration
EXO_INSTALL_DIR="/opt/exo"
STARTUP_SCRIPTS_DIR="scripts"

print_header "Starting exo installation and startup script tests..."

# Test 1: Check prerequisites
print_header "Test 1: Checking prerequisites..."

# Check Python version
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
if [[ "$python_version" == 3.12* ]] || [[ "$python_version" == 3.13* ]] || [[ "$python_version" == 3.14* ]]; then
    print_status "Python version $python_version is compatible"
else
    print_error "Python version $python_version is not compatible. Need Python 3.12+"
    exit 1
fi

# Check git
if command -v git &> /dev/null; then
    print_status "Git is installed"
else
    print_error "Git is not installed"
    exit 1
fi

# Test 2: Check startup scripts exist
print_header "Test 2: Checking startup scripts..."

required_files=(
    "$STARTUP_SCRIPTS_DIR/install_exo_service.sh"
    "$STARTUP_SCRIPTS_DIR/start_exo.sh"
    "$STARTUP_SCRIPTS_DIR/com.exolabs.exo.plist"
    "$STARTUP_SCRIPTS_DIR/uninstall_exo_service.sh"
    "$STARTUP_SCRIPTS_DIR/exo_config_example.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "Found $file"
    else
        print_error "Missing required file: $file"
        exit 1
    fi
done

# Test 3: Check script permissions
print_header "Test 3: Checking script permissions..."

for file in "${required_files[@]}"; do
    if [ -x "$file" ]; then
        print_status "$file is executable"
    else
        print_warning "$file is not executable, making it executable..."
        chmod +x "$file"
    fi
done

# Test 4: Validate plist file
print_header "Test 4: Validating plist file..."

if plutil -lint "$STARTUP_SCRIPTS_DIR/com.exolabs.exo.plist" > /dev/null 2>&1; then
    print_status "plist file is valid"
else
    print_error "plist file is invalid"
    exit 1
fi

# Test 5: Check if exo is already installed
print_header "Test 5: Checking existing exo installation..."

if [ -d "$EXO_INSTALL_DIR" ]; then
    print_warning "exo installation directory already exists at $EXO_INSTALL_DIR"
    print_warning "This test will not install exo if it already exists"
else
    print_status "No existing exo installation found"
fi

# Test 6: Test startup script functionality (without installing)
print_header "Test 6: Testing startup script functionality..."

# Test the startup script with status command
if [ -f "$EXO_INSTALL_DIR/scripts/start_exo.sh" ]; then
    print_status "Testing existing startup script..."
    if sudo "$EXO_INSTALL_DIR/scripts/start_exo.sh" status > /dev/null 2>&1; then
        print_status "Startup script status command works"
    else
        print_warning "Startup script status command failed (expected if not installed)"
    fi
else
    print_status "Startup script not yet installed (expected)"
fi

# Test 7: Check network connectivity
print_header "Test 7: Checking network connectivity..."

if curl -I https://github.com > /dev/null 2>&1; then
    print_status "GitHub is accessible"
else
    print_warning "GitHub is not accessible - installation may fail"
fi

if curl -I https://huggingface.co > /dev/null 2>&1; then
    print_status "Hugging Face is accessible"
else
    print_warning "Hugging Face is not accessible - model downloads may fail"
fi

# Test 8: Check port availability
print_header "Test 8: Checking port availability..."

if lsof -i :52415 > /dev/null 2>&1; then
    print_warning "Port 52415 is already in use"
else
    print_status "Port 52415 is available"
fi

# Test 9: Check system requirements
print_header "Test 9: Checking system requirements..."

# Check available memory
total_mem=$(sysctl -n hw.memsize | awk '{print $0/1024/1024/1024}')
print_status "Total system memory: ${total_mem}GB"

# Check available disk space
free_space=$(df /opt | tail -1 | awk '{print $4/1024/1024}')
print_status "Free disk space: ${free_space}GB"

if (( $(echo "$free_space < 5" | bc -l) )); then
    print_warning "Low disk space - at least 5GB recommended"
fi

# Test 10: Installation simulation
print_header "Test 10: Installation simulation..."

print_status "To install exo as a system service, run:"
echo "  sudo ./$STARTUP_SCRIPTS_DIR/install_exo_service.sh"
echo ""
print_status "After installation, you can:"
echo "  - Check service status: sudo launchctl list | grep exo"
echo "  - View logs: tail -f /var/log/exo/exo.log"
echo "  - Access web interface: http://localhost:52415"
echo "  - Test API: curl http://localhost:52415/v1/chat/completions"
echo ""
print_status "Configuration options:"
echo "  - Copy example config: cp $STARTUP_SCRIPTS_DIR/exo_config_example.sh /opt/exo/scripts/exo_config.sh"
echo "  - Edit configuration: nano /opt/exo/scripts/exo_config.sh"
echo "  - Restart service: sudo launchctl restart com.exolabs.exo"
echo ""
print_status "To uninstall:"
echo "  sudo ./$STARTUP_SCRIPTS_DIR/uninstall_exo_service.sh"

print_header "All tests completed successfully!"
print_status "The startup scripts are ready for installation" 