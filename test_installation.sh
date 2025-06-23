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

# Function to compare version numbers
version_compare() {
    local version1=$1
    local version2=$2
    local operator=$3
    
    # Convert versions to comparable format
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    # Fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    # Fill empty fields in ver2 with zeros
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    
    # Compare versions
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ ${ver1[i]} -lt ${ver2[i]} ]]; then
            [[ "$operator" == "<" || "$operator" == "<=" ]] && return 0 || return 1
        elif [[ ${ver1[i]} -gt ${ver2[i]} ]]; then
            [[ "$operator" == ">" || "$operator" == ">=" ]] && return 0 || return 1
        fi
    done
    
    # Versions are equal
    [[ "$operator" == "=" || "$operator" == ">=" || "$operator" == "<=" ]] && return 0 || return 1
}

# Test configuration
EXO_INSTALL_DIR="/opt/exo"
STARTUP_SCRIPTS_DIR="scripts"

print_header "Starting exo installation and startup script tests..."

# Test 1: Check prerequisites
print_header "Test 1: Checking prerequisites..."

# Use the same Python detection logic as the setup script
./scripts/setup_python_env.sh > /tmp/python_test.log 2>&1

if [[ -f "/tmp/exo_python_env" ]]; then
    source /tmp/exo_python_env
    print_status "Found compatible Python: $EXO_PYTHON_CMD (version $EXO_PYTHON_VERSION)"
    print_status "Python path: $EXO_PYTHON_PATH"
    rm -f /tmp/exo_python_env /tmp/python_test.log
else
    print_error "Python setup failed. Check the logs:"
    cat /tmp/python_test.log 2>/dev/null || echo "No log file found"
    rm -f /tmp/python_test.log
    exit 1
fi

# Check git
if command -v git &> /dev/null; then
    git_version=$(git --version | cut -d' ' -f3)
    print_status "Git is installed (version $git_version)"
else
    print_error "Git is not installed"
    echo "Install git using: brew install git"
    exit 1
fi

# Test 2: Check startup scripts exist
print_header "Test 2: Checking startup scripts..."

required_files=(
    "$STARTUP_SCRIPTS_DIR/install_exo_service.sh"
    "$STARTUP_SCRIPTS_DIR/setup_python_env.sh"
    "$STARTUP_SCRIPTS_DIR/start_exo.sh"
    "$STARTUP_SCRIPTS_DIR/check_exo_status.sh"
    "$STARTUP_SCRIPTS_DIR/com.exolabs.exo.plist"
    "$STARTUP_SCRIPTS_DIR/uninstall_exo_service.sh"
    "$STARTUP_SCRIPTS_DIR/exo_config_example.sh"
    "install_exo_auto.sh"
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

executable_files=(
    "$STARTUP_SCRIPTS_DIR/install_exo_service.sh"
    "$STARTUP_SCRIPTS_DIR/setup_python_env.sh"
    "$STARTUP_SCRIPTS_DIR/start_exo.sh"
    "$STARTUP_SCRIPTS_DIR/check_exo_status.sh"
    "$STARTUP_SCRIPTS_DIR/uninstall_exo_service.sh"
    "install_exo_auto.sh"
)

for file in "${executable_files[@]}"; do
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

# Test 5: Check network connectivity
print_header "Test 5: Checking network connectivity..."

if curl -I https://github.com > /dev/null 2>&1; then
    print_status "GitHub is accessible"
else
    print_warning "GitHub is not accessible - installation may fail"
fi

if curl -I https://pypi.org > /dev/null 2>&1; then
    print_status "PyPI is accessible"
else
    print_warning "PyPI is not accessible - pip installations may fail"
fi

# Test 6: Check port availability
print_header "Test 6: Checking port availability..."

if lsof -i :52415 > /dev/null 2>&1; then
    print_warning "Port 52415 is already in use"
    lsof -i :52415 | head -5
else
    print_status "Port 52415 is available"
fi

# Test 7: Check system requirements
print_header "Test 7: Checking system requirements..."

# Check available memory
if command -v sysctl &> /dev/null; then
    total_mem=$(sysctl -n hw.memsize 2>/dev/null | awk '{print $0/1024/1024/1024}' 2>/dev/null || echo "unknown")
    if [[ "$total_mem" != "unknown" ]]; then
        print_status "Total system memory: ${total_mem}GB"
        
        if (( $(echo "$total_mem < 8" | bc -l 2>/dev/null || echo "0") )); then
            print_warning "Less than 8GB RAM - performance may be limited"
        fi
    fi
else
    print_warning "Cannot determine system memory"
fi

# Check available disk space
free_space=$(df /opt 2>/dev/null | tail -1 | awk '{print $4/1024/1024}' 2>/dev/null || echo "unknown")
if [[ "$free_space" != "unknown" ]]; then
    print_status "Free disk space: ${free_space}GB"
    
    if (( $(echo "$free_space < 10" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "Low disk space - at least 10GB recommended for models"
    fi
else
    print_warning "Cannot determine available disk space"
fi

print_header "All tests completed successfully!"
print_status "Installation options:"
echo ""
print_status "Option 1 - Automated (Recommended):"
echo "  ./install_exo_auto.sh"
echo ""
print_status "Option 2 - Manual:"
echo "  ./scripts/setup_python_env.sh"
echo "  source /tmp/exo_python_env"  
echo "  sudo -E ./scripts/install_exo_service.sh"
echo ""
print_status "Python to be used: $EXO_PYTHON_CMD ($EXO_PYTHON_VERSION)" 