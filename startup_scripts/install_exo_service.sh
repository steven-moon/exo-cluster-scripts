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

# Configuration
EXO_INSTALL_DIR="/opt/exo"
LAUNCH_AGENTS_DIR="/Library/LaunchDaemons"
PLIST_FILE="com.exolabs.exo.plist"
STARTUP_SCRIPT="start_exo.sh"

print_status "Installing exo startup service..."

# Create exo installation directory
print_status "Creating installation directory: $EXO_INSTALL_DIR"
mkdir -p "$EXO_INSTALL_DIR/startup_scripts"

# Copy startup script
print_status "Installing startup script..."
cp "$STARTUP_SCRIPT" "$EXO_INSTALL_DIR/startup_scripts/"
chmod +x "$EXO_INSTALL_DIR/startup_scripts/$STARTUP_SCRIPT"

# Copy plist file
print_status "Installing launch daemon configuration..."
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Set proper permissions
chown root:wheel "$LAUNCH_AGENTS_DIR/$PLIST_FILE"
chmod 644 "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

# Create log directory
print_status "Creating log directory..."
mkdir -p /var/log/exo
chown root:wheel /var/log/exo
chmod 755 /var/log/exo

# Create PID file directory
mkdir -p /var/run
touch /var/run/exo.pid
chown root:wheel /var/run/exo.pid
chmod 644 /var/run/exo.pid

# Load the launch daemon
print_status "Loading launch daemon..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

print_status "Installation completed successfully!"
print_status "exo will now start automatically when the system boots"
print_status ""
print_status "To manage the service:"
print_status "  Start:   sudo launchctl start com.exolabs.exo"
print_status "  Stop:    sudo launchctl stop com.exolabs.exo"
print_status "  Status:  sudo launchctl list | grep exo"
print_status "  Logs:    tail -f /var/log/exo/exo.log"
print_status ""
print_status "To uninstall:"
print_status "  sudo launchctl unload $LAUNCH_AGENTS_DIR/$PLIST_FILE"
print_status "  sudo rm $LAUNCH_AGENTS_DIR/$PLIST_FILE"
print_status "  sudo rm -rf $EXO_INSTALL_DIR" 