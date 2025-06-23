#!/bin/bash

# Python environment setup script for exo installation
# This script ensures the correct Python version is available and configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[PYTHON-SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[PYTHON-SETUP]${NC} $1"
}

print_error() {
    echo -e "${RED}[PYTHON-SETUP]${NC} $1"
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

# Function to detect Homebrew prefix
detect_homebrew_prefix() {
    if [[ -d "/opt/homebrew" ]]; then
        echo "/opt/homebrew"
    elif [[ -d "/usr/local" ]] && [[ -f "/usr/local/bin/brew" ]]; then
        echo "/usr/local"
    else
        return 1
    fi
}

# Function to setup PATH for Python discovery
setup_python_path() {
    local homebrew_prefix=$(detect_homebrew_prefix)
    
    if [[ -n "$homebrew_prefix" ]]; then
        print_status "Found Homebrew at: $homebrew_prefix"
        
        # Add Homebrew paths to PATH
        export PATH="$homebrew_prefix/bin:$PATH"
        
        # Add specific Python version paths (in order of preference)
        local python_paths=(
            "$homebrew_prefix/opt/python@3.13/bin"
            "$homebrew_prefix/opt/python@3.12/bin" 
            "$homebrew_prefix/opt/python@3.11/bin"
            "$homebrew_prefix/opt/python@3.10/bin"
        )
        
        for path in "${python_paths[@]}"; do
            if [[ -d "$path" ]]; then
                export PATH="$path:$PATH"
            fi
        done
    fi
    
    # Also add common system paths
    export PATH="/usr/local/bin:/opt/local/bin:$PATH"
}

# Function to find compatible Python
find_compatible_python() {
    local python_candidates=("python3.13" "python3.12" "python3.11" "python3.10" "python3")
    
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

# Function to install Python via Homebrew
install_python_homebrew() {
    print_status "Installing Python 3.12 via Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_status "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Update PATH to include Homebrew
        local homebrew_prefix=$(detect_homebrew_prefix)
        if [[ -n "$homebrew_prefix" ]]; then
            export PATH="$homebrew_prefix/bin:$PATH"
        fi
    fi
    
    # Install Python 3.12
    if brew install python@3.12; then
        print_status "Python 3.12 installed successfully"
        
        # Force link it
        brew link --overwrite python@3.12 2>/dev/null || true
        
        # Update PATH to include the new Python
        setup_python_path
        
        return 0
    else
        return 1
    fi
}

# Main function
main() {
    print_status "Setting up Python environment for exo installation..."
    
    # Setup PATH for Python discovery
    setup_python_path
    
    # Try to find compatible Python
    if python_cmd=$(find_compatible_python); then
        python_version=$("$python_cmd" --version 2>&1 | cut -d' ' -f2)
        python_path=$(which "$python_cmd")
        
        print_status "Found compatible Python: $python_cmd (version $python_version)"
        print_status "Python path: $python_path"
        
        # Export for use by other scripts
        export EXO_PYTHON_CMD="$python_cmd"
        export EXO_PYTHON_VERSION="$python_version"
        export EXO_PYTHON_PATH="$python_path"
        
        # Write to a file for persistence
        cat > /tmp/exo_python_env << EOF
export EXO_PYTHON_CMD="$python_cmd"
export EXO_PYTHON_VERSION="$python_version" 
export EXO_PYTHON_PATH="$python_path"
export PATH="$PATH"
EOF
        
        print_status "Python environment ready!"
        print_status "Run: source /tmp/exo_python_env"
        print_status "Then: sudo -E ./scripts/install_exo_service.sh"
        
    else
        print_warning "No compatible Python version found"
        print_status "Attempting to install Python 3.12 via Homebrew..."
        
        if install_python_homebrew; then
            # Try again after installation
            if python_cmd=$(find_compatible_python); then
                python_version=$("$python_cmd" --version 2>&1 | cut -d' ' -f2)
                python_path=$(which "$python_cmd")
                
                print_status "Python installation successful!"
                print_status "Using: $python_cmd (version $python_version)"
                print_status "Path: $python_path"
                
                # Export for use by other scripts
                export EXO_PYTHON_CMD="$python_cmd"
                export EXO_PYTHON_VERSION="$python_version"
                export EXO_PYTHON_PATH="$python_path"
                
                # Write to a file for persistence
                cat > /tmp/exo_python_env << EOF
export EXO_PYTHON_CMD="$python_cmd"
export EXO_PYTHON_VERSION="$python_version"
export EXO_PYTHON_PATH="$python_path"
export PATH="$PATH"
EOF
                
                print_status "Python environment ready!"
                print_status "Run: source /tmp/exo_python_env"
                print_status "Then: sudo -E ./scripts/install_exo_service.sh"
                
            else
                print_error "Failed to find Python after installation"
                exit 1
            fi
        else
            print_error "Failed to install Python automatically"
            print_error "Please install Python 3.10+ manually and run this script again"
            exit 1
        fi
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 