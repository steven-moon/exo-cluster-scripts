#!/bin/bash

# exo status checker script
# Provides quick and detailed status reports for the exo service.

set -e

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Configuration
SERVICE_NAME="com.exolabs.exo"
LOG_FILE="/var/log/exo/exo.log"
PID_FILE="/var/run/exo.pid"
EXO_INSTALL_DIR="/opt/exo"
VENV_DIR="$EXO_INSTALL_DIR/venv"
EXO_PORT="52415"

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
        
        if [ -L "/usr/local/bin/exo" ] && [ -x "/usr/local/bin/exo" ]; then
            print_status "✓ System-wide exo command available"
        else
            print_error "✗ System-wide exo command not found or not a symlink"
        fi
    else
        print_error "✗ exo installation directory not found"
        return 1
    fi
}

# Function to check service status
check_service() {
    print_header "Service Status"
    
    local service_running=false
    local process_running=false
    local port_listening=false
    
    # Check if service is loaded (use sudo since service is loaded as root)
    if sudo launchctl list | grep -q "$SERVICE_NAME"; then
        print_status "✓ Service is loaded in launchctl"
        
        # Check if service is running (any non-zero PID means it's running)
        local service_pid
        service_pid=$(sudo launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$service_pid" != "0" ] && [ "$service_pid" != "-" ]; then
            service_running=true
        fi
    fi
    
    # Check process
    if pgrep -f "exo" > /dev/null 2>&1; then
        process_running=true
    fi
    
    # Check port
    if lsof -i :"$EXO_PORT" > /dev/null 2>&1; then
        port_listening=true
    fi
    
    # Determine overall status
    local status
    if $service_running && $process_running && $port_listening; then
        status="${GREEN}RUNNING${NC}"
    elif $service_running || $process_running; then
        status="${YELLOW}STARTING/DEGRADED${NC}"
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
        echo -e "✓ Web Interface: ${GREEN}http://localhost:$EXO_PORT${NC}"
    else
        echo -e "✗ Web Interface: ${RED}Not Available${NC}"
    fi
}

# Function to check system resources
check_resources() {
    print_header "System Resources"
    
    # Check CPU usage (user, system, idle)
    local cpu_usage
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print "User: " $3 ", System: " $5 ", Idle: " $7}')
    print_status "CPU usage: ${cpu_usage}"
    
    # Check memory usage
    local mem_usage
    mem_usage=$(top -l 1 | grep "PhysMem" | awk '{print "Used: " $2 ", Unused: " $6}')
    print_status "Memory usage: ${mem_usage}"

    # Check disk space for /opt
    if [ -d "/opt" ]; then
        local free_space
        free_space=$(df -h /opt | tail -1 | awk '{print $4}')
        print_status "Free disk space in /opt: ${free_space}B"
    fi
}

# Detailed status check
show_detailed_status() {
    print_header "=== exo Service Status Report ==="
    echo "Generated: $(date)"
    echo ""
    
    check_installation
    echo ""
    check_service
    echo ""
    check_resources
    echo ""
    
    # Log information
    print_header "Logs"
    if [ -f "$LOG_FILE" ]; then
        print_status "✓ Log file exists: $LOG_FILE"
        
        # Show recent errors
        local recent_errors
        recent_errors=$(tail -50 "$LOG_FILE" 2>/dev/null | grep -i "error\|exception\|failed" | wc -l | tr -d ' ')
        if [ "$recent_errors" -gt 0 ]; then
            print_warning "⚠ Found $recent_errors recent errors in logs. Last 5 error lines:"
            tail -50 "$LOG_FILE" 2>/dev/null | grep -i "error\|exception\|failed" | tail -5
        else
            print_status "✓ No recent errors found in logs"
        fi
    else
        print_error "✗ Log file not found: $LOG_FILE"
    fi
}

# Function to show quick status
show_quick_status() {
    local status
    
    # Check if service is loaded and running
    if sudo launchctl list | grep -q "$SERVICE_NAME"; then
        local service_pid
        service_pid=$(sudo launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$service_pid" != "0" ] && [ "$service_pid" != "-" ]; then
            status="${GREEN}RUNNING${NC}"
        else
            status="${YELLOW}LOADED (but not running)${NC}"
        fi
    else
        status="${RED}STOPPED${NC}"
    fi
    
    # Check if process is running
    local process_status
    if pgrep -f "exo" > /dev/null; then
        process_status="${GREEN}✓ Process${NC}"
    else
        process_status="${RED}✗ Process${NC}"
    fi
    
    # Check if port is listening
    local port_status
    if lsof -i :"$EXO_PORT" > /dev/null 2>&1; then
        port_status="${GREEN}✓ Port ${EXO_PORT}${NC}"
    else
        port_status="${RED}✗ Port ${EXO_PORT}${NC}"
    fi

    echo -e "Service: $status | $process_status | $port_status"
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