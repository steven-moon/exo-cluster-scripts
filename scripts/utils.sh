#!/bin/bash

# Shared utilities for exo installation scripts
# Source this file in other scripts with: source "$(dirname "$0")/utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Common print functions
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
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Simplified version comparison (just for basic needs)
version_compare() {
    local version1=$1
    local version2=$2
    local operator=$3
    
    # Use Python for reliable version comparison
    python3 -c "
import sys
from packaging import version
v1 = version.parse('$version1')
v2 = version.parse('$version2')
if '$operator' == '>=':
    sys.exit(0 if v1 >= v2 else 1)
elif '$operator' == '>':
    sys.exit(0 if v1 > v2 else 1)
elif '$operator' == '<=':
    sys.exit(0 if v1 <= v2 else 1)
elif '$operator' == '<':
    sys.exit(0 if v1 < v2 else 1)
elif '$operator' == '=':
    sys.exit(0 if v1 == v2 else 1)
else:
    sys.exit(1)
" 2>/dev/null || {
        # Fallback to simple string comparison if packaging module not available
        if [[ "$operator" == ">=" ]]; then
            [[ "$version1" == "$version2" ]] || [[ "$version1" > "$version2" ]]
        else
            # Add other operators as needed
            false
        fi
    }
}

# Detect Homebrew installation
detect_homebrew_prefix() {
    if [[ -d "/opt/homebrew" ]]; then
        echo "/opt/homebrew"
    elif [[ -d "/usr/local" ]] && [[ -f "/usr/local/bin/brew" ]]; then
        echo "/usr/local"
    else
        return 1
    fi
}

# Find compatible Python installation
find_compatible_python() {
    local python_candidates=("python3.13" "python3.12" "python3.11" "python3.10" "python3")
    
    # Setup PATH to include Homebrew
    local homebrew_prefix
    if homebrew_prefix=$(detect_homebrew_prefix); then
        export PATH="$homebrew_prefix/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.13/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.12/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.11/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.10/bin:$PATH"
    fi
    
    for cmd in "${python_candidates[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            local python_version=$("$cmd" --version 2>&1 | cut -d' ' -f2)
            
            if version_compare "$python_version" "3.10.0" ">="; then
                echo "$cmd"
                return 0
            fi
        fi
    done
    
    return 1
}

# Install Python via Homebrew
install_python_homebrew() {
    print_status "Installing Python 3.12 via Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_status "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
        
        # Update PATH to include Homebrew
        local homebrew_prefix
        if homebrew_prefix=$(detect_homebrew_prefix); then
            export PATH="$homebrew_prefix/bin:$PATH"
        fi
    fi
    
    # Install Python 3.12
    if brew install python@3.12; then
        print_status "Python 3.12 installed successfully"
        brew link --overwrite python@3.12 2>/dev/null || true
        return 0
    else
        return 1
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        return 1
    fi
    return 0
}

# Check if NOT running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root (without sudo)"
        print_error "The script will prompt for sudo when needed"
        return 1
    fi
    return 0
} 