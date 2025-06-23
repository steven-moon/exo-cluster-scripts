#!/bin/bash

# Uninstallation script for exo startup service on macOS

set -e

# Source utility functions using an absolute path
source "/opt/exo/scripts/utils.sh"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Configuration
EXO_INSTALL_DIR="/opt/exo"
LAUNCH_AGENTS_DIR="/Library/LaunchDaemons"
PLIST_FILE="com.exolabs.exo.plist"

print_header "Uninstalling exo startup service..."

# Stop and unload the launch daemon
print_status "Stopping and unloading exo service..."
if [ -f "$LAUNCH_AGENTS_DIR/$PLIST_FILE" ]; then
    launchctl stop com.exolabs.exo 2>/dev/null || true
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null || true
    print_status "Service stopped and unloaded."
else
    print_warning "Service configuration not found, skipping unload."
fi


# Remove files
print_status "Removing service configuration file..."
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

print_status "Removing system-wide commands..."
rm -f /usr/local/bin/exo
rm -f /usr/local/bin/exo-status

print_status "Removing installation directory..."
rm -rf "$EXO_INSTALL_DIR"

print_status "Removing log files..."
rm -rf /var/log/exo

print_status "Removing PID file..."
rm -f /var/run/exo.pid

print_header "Uninstallation completed successfully!" 