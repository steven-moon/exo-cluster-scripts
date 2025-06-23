#!/bin/bash

# ExoManager MCP Client Launcher
# This script starts the MCP client to receive real-time debug information from ExoManager

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
    echo -e "${BLUE}[MCP CLIENT]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_SCRIPT="$SCRIPT_DIR/exo_mcp_client.py"
DEFAULT_HOST="localhost"
DEFAULT_PORT="52417"

print_header "ExoManager MCP Client Launcher"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed"
    echo "Please install Python 3 and try again"
    exit 1
fi

# Check if client script exists
if [ ! -f "$CLIENT_SCRIPT" ]; then
    print_error "MCP client script not found: $CLIENT_SCRIPT"
    exit 1
fi

# Make sure the script is executable
chmod +x "$CLIENT_SCRIPT"

# Parse command line arguments
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --host HOST    MCP server host (default: localhost)"
            echo "  --port PORT    MCP server port (default: 52417)"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Connect to localhost:52417"
            echo "  $0 --host 192.168.1.100  # Connect to remote host"
            echo "  $0 --port 52418       # Connect to different port"
            echo ""
            echo "Make sure ExoManager is running and the MCP server is started."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

print_status "Starting MCP client..."
print_status "Connecting to: $HOST:$PORT"
echo ""

# Check if ExoManager is running
if ! pgrep -f "ExoManager" > /dev/null; then
    print_warning "ExoManager app doesn't appear to be running"
    print_warning "Make sure ExoManager is started to receive debug information"
    echo ""
fi

# Start the MCP client
print_status "Launching MCP client..."
echo "Press 'q' and Enter to quit"
echo ""

python3 "$CLIENT_SCRIPT" --host "$HOST" --port "$PORT" 