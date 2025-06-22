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

# Function to find exo executable
find_exo_executable() {
    # Check virtual environment first
    local venv_exo="/opt/exo/venv/bin/exo"
    if [ -x "$venv_exo" ]; then
        echo "$venv_exo"
        return 0
    fi
    
    # Check common locations for exo executable
    local exo_paths=(
        "/opt/exo/exo"
        "/usr/local/bin/exo"
        "/opt/homebrew/bin/exo"
        "/usr/bin/exo"
    )
    
    for path in "${exo_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find exo in PATH
    local exo_in_path=$(which exo 2>/dev/null)
    if [ -n "$exo_in_path" ]; then
        echo "$exo_in_path"
        return 0
    fi
    
    return 1
}

# Function to load configuration
load_configuration() {
    local config_file="/opt/exo/scripts/exo_config.sh"
    if [ -f "$config_file" ]; then
        log_message "Loading configuration from $config_file"
        source "$config_file"
    else
        log_message "No configuration file found, using defaults"
    fi
}

# Function to start exo
start_exo() {
    log_message "Starting exo cluster..."
    
    # Load configuration
    load_configuration
    
    # Find exo executable
    local exo_executable=$(find_exo_executable)
    if [ -z "$exo_executable" ]; then
        log_message "ERROR: exo executable not found. Please ensure exo is properly installed."
        return 1
    fi
    
    log_message "Found exo executable: $exo_executable"
    
    # Set environment variables
    export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
    
    # Set exo home directory (from config or default)
    export EXO_HOME="${EXO_HOME:-/opt/exo/.cache/exo}"
    
    # Create exo home directory if it doesn't exist
    mkdir -p "$EXO_HOME"
    
    # Change to exo directory for better compatibility
    cd /opt/exo
    
    # Build exo command with configuration
    local exo_cmd="$exo_executable"
    
    # Add discovery module if specified
    if [ -n "$EXO_DISCOVERY_MODULE" ]; then
        exo_cmd="$exo_cmd --discovery-module $EXO_DISCOVERY_MODULE"
    fi
    
    # Add Tailscale API key if specified
    if [ -n "$EXO_TAILSCALE_API_KEY" ]; then
        exo_cmd="$exo_cmd --tailscale-api-key $EXO_TAILSCALE_API_KEY"
    fi
    
    # Add manual peers if specified
    if [ -n "$EXO_MANUAL_PEERS" ]; then
        exo_cmd="$exo_cmd --manual-peers $EXO_MANUAL_PEERS"
    fi
    
    # Add web interface configuration
    if [ -n "$EXO_WEB_PORT" ]; then
        exo_cmd="$exo_cmd --port $EXO_WEB_PORT"
    fi
    
    if [ -n "$EXO_WEB_HOST" ]; then
        exo_cmd="$exo_cmd --host $EXO_WEB_HOST"
    fi
    
    # Add GPU memory fraction if specified
    if [ -n "$EXO_GPU_MEMORY_FRACTION" ]; then
        exo_cmd="$exo_cmd --gpu-memory-fraction $EXO_GPU_MEMORY_FRACTION"
    fi
    
    # Add default model if specified
    if [ -n "$EXO_DEFAULT_MODEL" ]; then
        exo_cmd="$exo_cmd --model $EXO_DEFAULT_MODEL"
    fi
    
    # Add extra arguments if specified
    if [ -n "$EXO_EXTRA_ARGS" ]; then
        exo_cmd="$exo_cmd $EXO_EXTRA_ARGS"
    fi
    
    # Start exo in the background
    log_message "Executing: $exo_cmd"
    $exo_cmd > "$LOG_FILE" 2>&1 &
    
    local exo_pid=$!
    echo "$exo_pid" > "$PID_FILE"
    
    log_message "exo started with PID: $exo_pid"
    
    # Wait a moment to check if it started successfully
    sleep 5
    if ps -p "$exo_pid" > /dev/null 2>&1; then
        log_message "exo is running successfully"
        log_message "Web interface available at: http://localhost:${EXO_WEB_PORT:-52415}"
        log_message "API endpoint available at: http://localhost:${EXO_WEB_PORT:-52415}/v1/chat/completions"
    else
        log_message "ERROR: exo failed to start"
        log_message "Check the log file for details: $LOG_FILE"
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