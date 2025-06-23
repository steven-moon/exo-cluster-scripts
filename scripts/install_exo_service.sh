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

# Global variables for Python detection
PYTHON_CMD=""
PYTHON_VERSION=""

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

# Function to find best Python version (silent - no output)
find_python() {
    local python_candidates=("python3.13" "python3.12" "python3.11" "python3.10" "python3")
    local python_cmd=""
    local python_version=""
    
    for cmd in "${python_candidates[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            python_version=$("$cmd" --version 2>&1 | cut -d' ' -f2)
            
            if version_compare "$python_version" "3.10.0" ">="; then
                python_cmd="$cmd"
                break
            fi
        fi
    done
    
    if [ -n "$python_cmd" ]; then
        echo "$python_cmd:$python_version"
        return 0
    else
        return 1
    fi
}

# Function to install Python via Homebrew
install_python_via_homebrew() {
    print_status "Installing Python via Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_status "Homebrew not found, installing Homebrew first..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            print_error "Failed to install Homebrew"
            return 1
        fi
        
        # Add Homebrew to PATH for current session
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            export PATH="/opt/homebrew/bin:$PATH"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            export PATH="/usr/local/bin:$PATH"
        fi
    fi
    
    # Install Python 3.12 (stable and well-supported)
    print_status "Installing Python 3.12 via Homebrew..."
    if brew install python@3.12; then
        print_status "Python 3.12 installed successfully"
        
        # Make sure it's properly linked
        brew link python@3.12 --force 2>/dev/null || true
        
        # Add Homebrew Python to PATH for current session
        if [[ -f "/opt/homebrew/bin/python3.12" ]]; then
            export PATH="/opt/homebrew/bin:$PATH"
        elif [[ -f "/usr/local/bin/python3.12" ]]; then
            export PATH="/usr/local/bin:$PATH"
        fi
        
        return 0
    else
        print_error "Failed to install Python 3.12 via Homebrew"
        return 1
    fi
}

# Function to setup Python environment
setup_python_environment() {
    # Detect Homebrew installation path
    local homebrew_prefix=""
    if [[ -d "/opt/homebrew" ]]; then
        homebrew_prefix="/opt/homebrew"
    elif [[ -d "/usr/local" ]]; then
        homebrew_prefix="/usr/local"
    fi
    
    # Add Homebrew paths to current session
    if [[ -n "$homebrew_prefix" ]]; then
        export PATH="$homebrew_prefix/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.12/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.11/bin:$PATH"
        export PATH="$homebrew_prefix/opt/python@3.10/bin:$PATH"
    fi
    
    # Try to find Python again with updated PATH
    python_info=$(find_python)
    if [ $? -eq 0 ]; then
        PYTHON_CMD=$(echo "$python_info" | cut -d':' -f1)
        PYTHON_VERSION=$(echo "$python_info" | cut -d':' -f2)
        return 0
    else
        return 1
    fi
}

# Function to check Python prerequisites
check_python_prerequisites() {
    print_status "Checking Python prerequisites..."
    
    # Check if Python environment variables are already set (from setup script)
    if [[ -n "$EXO_PYTHON_CMD" ]] && [[ -n "$EXO_PYTHON_VERSION" ]]; then
        print_status "Using pre-configured Python environment:"
        PYTHON_CMD="$EXO_PYTHON_CMD"
        PYTHON_VERSION="$EXO_PYTHON_VERSION"
        print_status "Python command: $PYTHON_CMD"
        print_status "Python version: $PYTHON_VERSION"
        print_status "Python path: $EXO_PYTHON_PATH"
    else
        # First, try to find existing compatible Python
        print_status "Searching for compatible Python installation..."
        if setup_python_environment; then
            print_status "Found compatible Python: $PYTHON_CMD (version $PYTHON_VERSION)"
        else
            print_warning "No compatible Python version found"
            print_status "Attempting to install Python automatically..."
            
            # Try to install Python via Homebrew
            if install_python_via_homebrew; then
                # Try to find Python again after installation
                if setup_python_environment; then
                    print_status "Python installation successful: $PYTHON_CMD (version $PYTHON_VERSION)"
                else
                    print_error "Failed to find Python after installation"
                    exit 1
                fi
            else
                print_error "Failed to install Python automatically"
                print_error "Please install Python 3.10+ manually or run:"
                echo "  ./scripts/setup_python_env.sh"
                echo "  source /tmp/exo_python_env"
                echo "  sudo -E ./scripts/install_exo_service.sh"
                exit 1
            fi
        fi
    fi
    
    # Verify Python path
    python_path=$(which "$PYTHON_CMD")
    print_status "Python path: $python_path"
    
    # Check if we can create virtual environments
    if ! "$PYTHON_CMD" -m venv --help > /dev/null 2>&1; then
        print_error "Python virtual environment support is not available for $PYTHON_CMD"
        print_error "Try installing python3-venv package or use a different Python installation"
        exit 1
    fi
    
    # Check if pip is available
    if ! "$PYTHON_CMD" -m pip --version > /dev/null 2>&1; then
        print_error "pip is not available for $PYTHON_CMD"
        print_error "Try installing python3-pip package"
        exit 1
    fi
    
    print_status "Python prerequisites check passed"
}

# Function to test key dependencies before full installation
test_dependencies() {
    print_status "Testing key dependencies before installation..."
    
    # Create a temporary virtual environment to test dependencies
    local temp_venv="/tmp/exo_dep_test_$$"
    
    if "$PYTHON_CMD" -m venv "$temp_venv"; then
        print_status "Created temporary test environment"
        
        # Activate the temporary environment
        source "$temp_venv/bin/activate"
        
        # Upgrade pip
        pip install --quiet --upgrade pip
        
        # Test tinygrad (the main problematic dependency)
        print_status "Testing tinygrad installation..."
        if pip install --quiet "tinygrad==0.10.0" > /dev/null 2>&1; then
            print_status "✓ tinygrad can be installed successfully"
        else
            print_error "✗ tinygrad installation failed"
            print_error "This is usually due to Python version incompatibility"
            deactivate
            rm -rf "$temp_venv"
            exit 1
        fi
        
        # Test MLX if on Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            print_status "Testing MLX installation on Apple Silicon..."
            if pip install --quiet "mlx==0.26.1" > /dev/null 2>&1; then
                print_status "✓ MLX can be installed successfully"
            else
                print_warning "⚠ MLX installation failed - Apple Silicon features may not work optimally"
            fi
        fi
        
        deactivate
        rm -rf "$temp_venv"
        print_status "Dependency test completed successfully"
    else
        print_error "Failed to create temporary test environment"
        exit 1
    fi
}

# Function to create directories with proper permissions
create_directories() {
    print_status "Creating installation directory: $EXO_INSTALL_DIR"
    mkdir -p "$EXO_INSTALL_DIR"
    
    print_status "Creating startup scripts directory..."
    mkdir -p "$EXO_INSTALL_DIR/scripts"
    
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
        
        if ! git fetch origin; then
            print_error "Failed to fetch updates from repository"
            print_error "Check your internet connection"
            exit 1
        fi
        
        git reset --hard origin/main
    elif [ -d "$EXO_INSTALL_DIR" ]; then
        print_warning "Directory $EXO_INSTALL_DIR exists but is not a git repository"
        print_status "Removing existing directory and cloning fresh repository..."
        rm -rf "$EXO_INSTALL_DIR"
        
        if ! git clone "$EXO_REPO_URL" "$EXO_INSTALL_DIR"; then
            print_error "Failed to clone exo repository"
            print_error "Check your internet connection and GitHub access"
            exit 1
        fi
    else
        print_status "Cloning exo repository from GitHub..."
        
        if ! git clone "$EXO_REPO_URL" "$EXO_INSTALL_DIR"; then
            print_error "Failed to clone exo repository"
            print_error "Check your internet connection and GitHub access"
            exit 1
        fi
    fi
    
    cd "$EXO_INSTALL_DIR"
    print_status "Repository setup completed successfully"
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
        print_status "Creating Python virtual environment using $PYTHON_CMD..."
        "$PYTHON_CMD" -m venv "$VENV_DIR"
    else
        print_status "Virtual environment already exists"
    fi
    
    print_status "Installing exo in virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip in virtual environment
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Fix numpy compatibility issue with Python 3.13
    if version_compare "$PYTHON_VERSION" "3.13.0" ">="; then
        print_status "Detected Python 3.13+, installing compatible numpy version..."
        pip install "numpy<2.0.0"
    fi
    
    # Install exo in development mode with better error handling
    print_status "Installing exo using pip install -e ."
    if ! pip install -e .; then
        print_error "Failed to install exo"
        print_error "Check the error messages above for details"
        deactivate
        exit 1
    fi
    
    print_status "Verifying exo installation..."
    if ! python -c "import exo" 2>/dev/null; then
        print_error "exo installation verification failed"
        deactivate
        exit 1
    fi
    
    deactivate
    print_status "Virtual environment setup completed successfully"
}

# Function to install startup scripts
install_startup_scripts() {
    print_status "Installing startup script..."
    mkdir -p "$EXO_INSTALL_DIR/scripts"
    cp "$SCRIPT_DIR/$STARTUP_SCRIPT" "$EXO_INSTALL_DIR/scripts/"
    chmod +x "$EXO_INSTALL_DIR/scripts/$STARTUP_SCRIPT"
    
    print_status "Installing status checker script..."
    cp "$SCRIPT_DIR/check_exo_status.sh" "$EXO_INSTALL_DIR/scripts/"
    chmod +x "$EXO_INSTALL_DIR/scripts/check_exo_status.sh"
    
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
    
    # Check if system-wide exo command exists
    if [ -x "/usr/local/bin/exo" ]; then
        print_status "✓ System-wide exo command available"
    else
        print_error "✗ System-wide exo command not found"
        return 1
    fi
    
    # Check if system-wide exo-status command exists
    if [ -x "/usr/local/bin/exo-status" ]; then
        print_status "✓ System-wide exo-status command available"
    else
        print_error "✗ System-wide exo-status command not found"
        return 1
    fi
    
    # Check if startup script exists
    if [ -x "$EXO_INSTALL_DIR/scripts/$STARTUP_SCRIPT" ]; then
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

# Function to create system-wide exo command
create_exo_command() {
    print_status "Creating system-wide exo command..."
    
    # Create symlink in /usr/local/bin (standard location for user-installed binaries)
    local exo_symlink="/usr/local/bin/exo"
    local exo_executable="$VENV_DIR/bin/exo"
    
    if [ -x "$exo_executable" ]; then
        # Remove existing symlink if it exists
        if [ -L "$exo_symlink" ]; then
            rm "$exo_symlink"
        fi
        
        # Create new symlink
        ln -sf "$exo_executable" "$exo_symlink"
        chmod +x "$exo_symlink"
        
        print_status "✓ exo command available at: $exo_symlink"
        print_status "✓ You can now run 'exo --help' from anywhere"
    else
        print_error "✗ exo executable not found at $exo_executable"
        return 1
    fi
}

# Function to create system-wide exo-status command
create_exo_status_command() {
    print_status "Creating system-wide exo-status command..."
    
    # Create symlink in /usr/local/bin
    local status_symlink="/usr/local/bin/exo-status"
    local status_script="$EXO_INSTALL_DIR/scripts/check_exo_status.sh"
    
    if [ -x "$status_script" ]; then
        # Remove existing symlink if it exists
        if [ -L "$status_symlink" ]; then
            rm "$status_symlink"
        fi
        
        # Create new symlink
        ln -sf "$status_script" "$status_symlink"
        chmod +x "$status_symlink"
        
        print_status "✓ exo-status command available at: $status_symlink"
        print_status "✓ You can now run 'exo-status' or 'exo-status quick' from anywhere"
    else
        print_error "✗ Status script not found at $status_script"
        return 1
    fi
}

# Main installation process
main() {
    print_status "Starting exo installation process..."
    
    # Check prerequisites first
    check_python_prerequisites
    test_dependencies
    
    check_existing_installation
    create_directories
    setup_exo_repository
    configure_mlx
    setup_virtual_environment
    install_startup_scripts
    create_exo_command
    create_exo_status_command
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
        print_status "  - Python version: $PYTHON_CMD ($PYTHON_VERSION)"
        print_status "  - MLX version: Updated to 0.26.1"
        print_status "  - exo command: /usr/local/bin/exo"
        print_status "  - exo-status command: /usr/local/bin/exo-status"
        print_status "  - Web interface: http://localhost:52415"
        print_status "  - API endpoint: http://localhost:52415/v1/chat/completions"
        print_status ""
        print_status "To manage the service:"
        print_status "  Start:   sudo launchctl start com.exolabs.exo"
        print_status "  Stop:    sudo launchctl stop com.exolabs.exo"
        print_status "  Status:  sudo launchctl list | grep exo"
        print_status "  Logs:    tail -f /var/log/exo/exo.log"
        print_status ""
        print_status "To test exo command:"
        print_status "  exo --help"
        print_status ""
        print_status "To check service status:"
        print_status "  exo-status          # Full status report"
        print_status "  exo-status quick    # Quick status summary"
        print_status ""
        print_status "To uninstall:"
        print_status "  sudo ./scripts/uninstall_exo_service.sh"
    else
        print_error "Installation verification failed. Please check the logs and try again."
        exit 1
    fi
}

# Run main installation
main 