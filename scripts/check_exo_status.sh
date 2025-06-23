#!/bin/bash

# exo status checker script
# This script provides detailed status information about the exo service

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
EXO_INSTALL_DIR="/opt/exo"
VENV_DIR="$EXO_INSTALL_DIR/venv"
LOG_FILE="/var/log/exo/exo.log"
PID_FILE="/var/run/exo.pid"
SERVICE_NAME="com.exolabs.exo"

# Function to check if exo is installed
check_installation() {
    print_header "Installation Status"
    
    if [ -d "$EXO_INSTALL_DIR" ]; then
        print_status "✓ exo installation directory exists: $EXO_INSTALL_DIR"
        
        if [ -d "$EXO_INSTALL_DIR/.git" ]; then
            print_status "✓ Git repository found"
        else
            print_warning "⚠ Git repository not found"
        fi
        
        if [ -d "$VENV_DIR" ]; then
            print_status "✓ Virtual environment exists: $VENV_DIR"
        else
            print_error "✗ Virtual environment not found"
        fi
        
        if [ -x "/usr/local/bin/exo" ]; then
            print_status "✓ System-wide exo command available"
        else
            print_error "✗ System-wide exo command not found"
        fi
    else
        print_error "✗ exo installation directory not found"
        return 1
    fi
}

# Function to check service status
check_service() {
    print_header "Service Status"
    
    # Check if service is loaded (script must be run as root)
    if launchctl list | grep -q "$SERVICE_NAME"; then
        print_status "✓ Service is loaded in launchctl"
        
        # Check if service is running (any non-zero PID means it's running)
        local service_pid=$(launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$service_pid" != "0" ] && [ "$service_pid" != "-" ]; then
            print_status "✓ Service is running (PID: $service_pid)"
        else
            print_warning "⚠ Service is loaded but may not be running"
        fi
    else
        print_error "✗ Service is not loaded in launchctl"
    fi
    
    # Check if plist file exists
    if [ -f "/Library/LaunchDaemons/$SERVICE_NAME.plist" ]; then
        print_status "✓ Launch daemon configuration exists"
    else
        print_error "✗ Launch daemon configuration not found"
    fi
}

# Function to check process status
check_process() {
    print_header "Process Status"
    
    # Check if exo process is running
    if pgrep -f "exo" > /dev/null; then
        local pids=$(pgrep -f "exo")
        print_status "✓ exo process is running (PIDs: $pids)"
        
        # Show process details
        for pid in $pids; do
            if ps -p "$pid" > /dev/null 2>&1; then
                local cmd=$(ps -p "$pid" -o command= | head -1)
                local mem=$(ps -p "$pid" -o rss= | head -1)
                local cpu=$(ps -p "$pid" -o %cpu= | head -1)
                print_status "  PID $pid: $cmd"
                print_status "    Memory: ${mem}KB, CPU: ${cpu}%"
            fi
        done
    else
        print_error "✗ No exo process found running"
    fi
    
    # Check PID file
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            print_status "✓ PID file exists and contains valid PID: $pid"
        else
            print_warning "⚠ PID file exists but contains invalid PID: $pid"
        fi
    else
        print_warning "⚠ PID file not found"
    fi
}

# Function to check network status
check_network() {
    print_header "Network Status"
    
    # Check if port 52415 is listening
    if lsof -i :52415 > /dev/null 2>&1; then
        print_status "✓ Port 52415 is listening"
        lsof -i :52415 | grep LISTEN | while read line; do
            print_status "  $line"
        done
    else
        print_error "✗ Port 52415 is not listening"
    fi
    
    # Check if web interface is accessible
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:52415 | grep -q "200\|302"; then
        print_status "✓ Web interface is accessible at http://localhost:52415"
    else
        print_warning "⚠ Web interface may not be accessible"
    fi
}

# Function to check logs
check_logs() {
    print_header "Log Status"
    
    if [ -f "$LOG_FILE" ]; then
        print_status "✓ Log file exists: $LOG_FILE"
        
        # Show log file size
        local size=$(du -h "$LOG_FILE" | cut -f1)
        print_status "  Log file size: $size"
        
        # Show last few log entries
        print_status "  Last 5 log entries:"
        tail -5 "$LOG_FILE" | while read line; do
            echo "    $line"
        done
        
        # Check for recent errors
        local recent_errors=$(tail -50 "$LOG_FILE" | grep -i "error\|exception\|traceback" | wc -l)
        if [ "$recent_errors" -gt 0 ]; then
            print_warning "⚠ Found $recent_errors recent errors in logs"
        else
            print_status "✓ No recent errors found in logs"
        fi
    else
        print_error "✗ Log file not found: $LOG_FILE"
    fi
}

# Function to check system resources
check_resources() {
    print_header "System Resources"
    
    # Check available memory
    local total_mem=$(sysctl -n hw.memsize | awk '{print $0/1024/1024/1024}')
    local free_mem=$(vm_stat | grep "Pages free:" | awk '{print $3}' | sed 's/\.//' | awk '{print $1/1024/1024/1024}')
    print_status "Total memory: ${total_mem}GB"
    print_status "Free memory: ${free_mem}GB"
    
    # Check disk space
    local free_space=$(df /opt | tail -1 | awk '{print $4/1024/1024}')
    print_status "Free disk space: ${free_space}GB"
    
    # Check CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    print_status "CPU usage: ${cpu_usage}%"
}

# Function to show quick status
show_quick_status() {
    local status=""
    
    # Check if service is loaded and running (script must be run as root)
    if launchctl list | grep -q "$SERVICE_NAME"; then
        local service_pid=$(launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$service_pid" != "0" ] && [ "$service_pid" != "-" ]; then
            status="${GREEN}RUNNING${NC}"
        else
            status="${YELLOW}LOADED${NC}"
        fi
    else
        status="${RED}STOPPED${NC}"
    fi
    
    # Check if process is running
    local process_status=""
    if pgrep -f "exo" > /dev/null; then
        process_status="${GREEN}✓${NC}"
    else
        process_status="${RED}✗${NC}"
    fi
    
    # Check if port is listening
    local port_status=""
    if lsof -i :52415 > /dev/null 2>&1; then
        port_status="${GREEN}✓${NC}"
    else
        port_status="${RED}✗${NC}"
    fi
    
    echo -e "exo Status: $status | Process: $process_status | Port: $port_status"
}

# Main function
main() {
    case "${1:-full}" in
        "quick")
            show_quick_status
            ;;
        "full"|"")
            echo "=== exo Service Status Report ==="
            echo "Generated: $(date)"
            echo ""
            
            check_installation
            echo ""
            check_service
            echo ""
            check_process
            echo ""
            check_network
            echo ""
            check_logs
            echo ""
            check_resources
            echo ""
            
            print_header "Quick Summary"
            show_quick_status
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  quick    Show quick status summary"
            echo "  full     Show detailed status report (default)"
            echo "  help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0          # Full status report"
            echo "  $0 quick    # Quick status"
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 