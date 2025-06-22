#!/bin/bash

# exo startup script for macOS
# This script runs exo in the background when the system starts

# Set up logging
LOG_DIR="/var/log/exo"
LOG_FILE="$LOG_DIR/exo.log"
PID_FILE="/var/run/exo.pid"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if exo is already running
is_exo_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            # PID file exists but process is dead, clean it up
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Function to start exo
start_exo() {
    log_message "Starting exo cluster..."
    
    # Set environment variables
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    export PYTHONPATH="/opt/exo:$PYTHONPATH"
    
    # Set exo home directory (adjust as needed)
    export EXO_HOME="/opt/exo/.cache/exo"
    
    # Create exo home directory if it doesn't exist
    mkdir -p "$EXO_HOME"
    
    # Start exo in the background
    # Use a different approach that works better with LaunchDaemons
    # Redirect output to log file and run in background
    exo > "$LOG_FILE" 2>&1 &
    
    local exo_pid=$!
    echo "$exo_pid" > "$PID_FILE"
    
    log_message "exo started with PID: $exo_pid"
    
    # Wait a moment to check if it started successfully
    sleep 3
    if ps -p "$exo_pid" > /dev/null 2>&1; then
        log_message "exo is running successfully"
    else
        log_message "ERROR: exo failed to start"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Function to stop exo
stop_exo() {
    log_message "Stopping exo cluster..."
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid"
            log_message "Sent SIGTERM to exo process (PID: $pid)"
            
            # Wait for graceful shutdown
            local count=0
            while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 30 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid"
                log_message "Force killed exo process (PID: $pid)"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    log_message "exo stopped"
}

# Main execution
case "$1" in
    start)
        if is_exo_running; then
            log_message "exo is already running"
            exit 0
        fi
        start_exo
        ;;
    stop)
        stop_exo
        ;;
    restart)
        stop_exo
        sleep 2
        start_exo
        ;;
    status)
        if is_exo_running; then
            echo "exo is running"
            exit 0
        else
            echo "exo is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac 