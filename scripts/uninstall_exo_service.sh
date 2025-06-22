#!/bin/bash

# Uninstallation script for exo startup service on macOS

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

print_status "Uninstalling exo startup service..."

# Stop and unload the launch daemon
print_status "Stopping exo service..."
launchctl stop com.exolabs.exo 2>/dev/null || true

print_status "Unloading launch daemon..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null || true

# Remove files
print_status "Removing configuration files..."
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

print_status "Removing system-wide exo command..."
rm -f /usr/local/bin/exo

# Remove system-wide exo-status command
print_status "Removing system-wide exo-status command..."
rm -f /usr/local/bin/exo-status

print_status "Removing installation directory..."
rm -rf "$EXO_INSTALL_DIR"

print_status "Removing log files..."
rm -rf /var/log/exo

print_status "Removing PID file..."
rm -f /var/run/exo.pid

print_status "Uninstallation completed successfully!" 