#!/bin/bash

# exo status checker script
# Simplified version focusing on essential information

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
    echo -e "${BLUE}[STATUS]${NC} $1"
}

# Configuration
SERVICE_NAME="com.exolabs.exo"
LOG_FILE="/var/log/exo/exo.log"

# Quick status check
show_quick_status() {
    local status=""
    local service_running=false
    local process_running=false
    local port_listening=false
    
    # Check service status
    if sudo launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
        local service_pid=$(sudo launchctl list | grep "$SERVICE_NAME" | awk '{print $1}' 2>/dev/null)
        if [ "$service_pid" != "0" ] && [ "$service_pid" != "-" ]; then
            service_running=true
        fi
    fi
    
    # Check process
    if pgrep -f "exo" > /dev/null 2>&1; then
        process_running=true
    fi
    
    # Check port
    if lsof -i :52415 > /dev/null 2>&1; then
        port_listening=true
    fi
    
    # Determine overall status
    if $service_running && $process_running && $port_listening; then
        status="${GREEN}RUNNING${NC}"
    elif $service_running || $process_running; then
        status="${YELLOW}STARTING${NC}"
    else
        status="${RED}STOPPED${NC}"
    fi
    
    echo -e "exo Status: $status"
    
    if $service_running; then
        echo -e "✓ Service: ${GREEN}Active${NC}"
    else
        echo -e "✗ Service: ${RED}Inactive${NC}"
    fi
    
    if $process_running; then
        echo -e "✓ Process: ${GREEN}Running${NC}"
    else
        echo -e "✗ Process: ${RED}Not Running${NC}"
    fi
    
    if $port_listening; then
        echo -e "✓ Web Interface: ${GREEN}http://localhost:52415${NC}"
    else
        echo -e "✗ Web Interface: ${RED}Not Available${NC}"
    fi
}

# Detailed status check
show_detailed_status() {
    echo "=== exo Service Status Report ==="
    echo "Generated: $(date)"
    echo ""
    
    show_quick_status
    echo ""
    
    # Installation check
    print_header "Installation"
    if [ -d "/opt/exo" ]; then
        print_status "✓ Installation directory exists"
        if [ -x "/opt/exo/venv/bin/exo" ]; then
            print_status "✓ exo executable found"
        else
            print_error "✗ exo executable missing"
        fi
    else
        print_error "✗ Installation directory not found"
    fi
    
    # Log information
    echo ""
    print_header "Logs"
    if [ -f "$LOG_FILE" ]; then
        print_status "✓ Log file exists: $LOG_FILE"
        
        # Show recent errors
        local recent_errors=$(tail -50 "$LOG_FILE" 2>/dev/null | grep -i "error\|exception\|failed" | wc -l | tr -d ' ')
        if [ "$recent_errors" -gt 0 ]; then
            print_warning "⚠ Found $recent_errors recent errors in logs"
            echo "  Recent errors:"
            tail -50 "$LOG_FILE" 2>/dev/null | grep -i "error\|exception\|failed" | tail -3 | sed 's/^/    /'
        else
            print_status "✓ No recent errors found"
        fi
        
        # Show last few entries
        echo "  Last 3 log entries:"
        tail -3 "$LOG_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (unable to read log)"
    else
        print_error "✗ Log file not found"
    fi
}

# Main function
main() {
    case "${1:-quick}" in
        "quick"|"")
            show_quick_status
            ;;
        "full"|"detailed")
            show_detailed_status
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  quick     Show quick status summary (default)"
            echo "  full      Show detailed status report"
            echo "  help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0          # Quick status"
            echo "  $0 quick    # Quick status"
            echo "  $0 full     # Detailed status"
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 