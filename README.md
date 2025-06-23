# Exo Cluster Scripts & ExoManager

A comprehensive solution for managing the Exo AI cluster server on macOS, including installation scripts and a native macOS management application.

## Overview

This repository contains:

1. **Shell Scripts**: Automated installation, configuration, and management scripts for the Exo AI cluster
2. **ExoManager**: A native macOS application providing a modern GUI for managing Exo services

## Features

### Shell Scripts
- **Automated Installation**: One-command installation of Exo as a system service
- **Service Management**: Start, stop, restart, and status checking
- **Configuration Management**: Environment-based configuration system
- **Logging**: Comprehensive logging and monitoring
- **Uninstallation**: Clean removal of all components

### ExoManager macOS App
- **Service Management**: Install, uninstall, start, stop, and restart Exo services
- **Real-time Monitoring**: CPU, memory, disk, and GPU usage tracking
- **Network Discovery**: Find and manage other Exo nodes on the network
- **Embedded Chat Interface**: Access the Exo web interface directly in the app
- **Log Management**: Real-time log viewing with filtering and export
- **Performance Controls**: Adjust throttling settings for optimal performance
- **Configuration Management**: User-friendly settings interface
- **Dashboard**: Overview of system status and quick actions

## Real-Time Debugging with MCP Server

ExoManager includes a built-in MCP (Model Context Protocol) server that streams real-time debug information, logs, and performance metrics to Cursor IDE or any other client.

### Features

- **Real-time Log Streaming**: Live log entries from the Exo service
- **Performance Metrics**: CPU, memory, disk, and GPU usage
- **Service Status**: Installation, running status, and error messages
- **Network Discovery**: Node discovery and cluster information
- **Debug Messages**: Custom debug messages from different components

### Using the MCP Client

#### Quick Start

1. **Start ExoManager** (the MCP server starts automatically)
2. **Run the MCP client** in Cursor IDE:
   ```bash
   ./scripts/start_mcp_client.sh
   ```

#### Manual Client Usage

```bash
# Connect to local ExoManager
python3 scripts/exo_mcp_client.py

# Connect to remote ExoManager
python3 scripts/exo_mcp_client.py --host 192.168.1.100 --port 52417

# Get help
./scripts/start_mcp_client.sh --help
```

#### Client Features

- **Colored Output**: Different colors for errors, warnings, and info messages
- **Real-time Updates**: Live streaming of all debug information
- **Statistics**: Message counts and performance averages
- **Easy Quit**: Press 'q' and Enter to disconnect

### MCP Server Details

- **Port**: 52417 (configurable)
- **Protocol**: TCP with JSON messages
- **Auto-start**: Server starts automatically when ExoManager launches
- **Multiple Clients**: Supports multiple simultaneous connections

### Message Types

| Type | Description | Frequency |
|------|-------------|-----------|
| `welcome` | Server connection info | On connect |
| `log_entry` | Exo service logs | Real-time |
| `performance_metrics` | System performance | Every 2 seconds |
| `service_status` | Service state | Every 5 seconds |
| `network_discovery` | Network nodes | Every 10 seconds |
| `debug_message` | Custom debug info | On events |

### Integration with Cursor IDE

The MCP client provides real-time debugging information that appears directly in your Cursor IDE terminal, making it easy to:

- Monitor Exo service installation and startup
- Debug performance issues
- Track network discovery
- View live logs without switching applications
- Get immediate feedback on service operations

### Example Output

```
🎉 Connected to ExoManager MCP Server v1.0.0
   📋 Capabilities: logs, performance, service_status, network_discovery
------------------------------------------------------------
🔍 [14:30:15] [app] ExoManager app started
📊 [14:30:16] CPU: 45.2% | Memory: 67.8% | Disk: 23.1% | GPU: 12.4%
   🌐 Network: Connected | Web: 🟢 | API: 🟢
🔧 [14:30:17] Service: ⚪ Not Installed
🔍 [14:30:18] [service_manager] Starting Exo service installation
❌ [14:30:19] [ERROR] Installation failed: Permission denied
```

## Quick Start

### Using Shell Scripts

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/exo-cluster-scripts.git
   cd exo-cluster-scripts
   ```

2. **Install Exo**:
   ```bash
   sudo ./scripts/install_exo_service.sh
   ```

3. **Check status**:
   ```bash
   ./scripts/check_exo_status.sh
   ```

4. **Start/stop service**:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.exolabs.exo.plist
   sudo launchctl unload /Library/LaunchDaemons/com.exolabs.exo.plist
   ```

### Using ExoManager App

**Quick Start (Recommended)**:
```bash
# Build and install to Applications
./build.sh --install

# Launch with administrator privileges
./build.sh --launch
```

**Alternative Options**:
```bash
# Build and run immediately
./build.sh --run

# Build only
./build.sh

# Create DMG installer
./build.sh --dmg

# Launch existing app (no build)
./build.sh --launch
```

**Note**: ExoManager requires administrator privileges to install and manage system services. If the app freezes during installation, it's likely a privilege escalation issue. Use one of the methods above to run with proper privileges.

## Requirements

### System Requirements
- macOS 14.0 or later
- Administrator privileges (for service installation)
- Xcode command line tools (for building ExoManager)

### Dependencies
- Python 3.8+ (for Exo)
- Git (for repository cloning)
- Homebrew (optional, for additional tools)

## Installation

### Shell Scripts Only

If you only want to use the shell scripts:

```bash
# Clone the repository
git clone https://github.com/your-username/exo-cluster-scripts.git
cd exo-cluster-scripts

# Make scripts executable
chmod +x scripts/*.sh

# Install Exo service
sudo ./scripts/install_exo_service.sh
```

### ExoManager App

To build and install the ExoManager app:

```bash
# Clone the repository
git clone https://github.com/your-username/exo-cluster-scripts.git
cd exo-cluster-scripts

# Build the app
./build.sh

# Install the app
cd dist
./install.sh
```

## Configuration

### Shell Scripts Configuration

Edit `/opt/exo/scripts/exo_config.sh` to customize Exo settings:

```bash
# Basic configuration
export EXO_HOME="/opt/exo/.cache/exo"
export HF_ENDPOINT="https://huggingface.co"
export DEBUG=0

# Network configuration
export EXO_DISCOVERY_MODULE="udp"
export EXO_WEB_PORT="52415"
export EXO_WEB_HOST="0.0.0.0"

# Performance configuration
export EXO_GPU_MEMORY_FRACTION="0.9"
export EXO_DEFAULT_MODEL="llama-3.2-3b"
```

### ExoManager Configuration

All configuration is managed through the app's Settings interface:

1. Launch ExoManager
2. Go to Settings (⌘,)
3. Configure settings in the appropriate tabs:
   - **Basic**: Installation directory, debug level
   - **Network**: Discovery settings, web interface
   - **Performance**: GPU memory, throttling controls
   - **Advanced**: Command line arguments, debugging

## Usage

### Shell Scripts

| Script | Purpose |
|--------|---------|
| `install_exo_service.sh` | Install Exo as a system service |
| `uninstall_exo_service.sh` | Remove Exo service and files |
| `start_exo.sh` | Start the Exo service |
| `check_exo_status.sh` | Check service status and health |
| `exo_config_example.sh` | Example configuration file |

### ExoManager App

#### Dashboard
- Monitor service status and system resources
- Quick actions for common tasks
- Network health overview

#### Chat
- Embedded web interface for Exo chat
- Navigation controls and error handling
- Direct access to Exo API

#### Performance
- Real-time charts for CPU, memory, disk, and GPU
- Historical data with selectable time ranges
- Performance metrics and statistics

#### Network
- Discover other Exo nodes on the network
- Node details and cluster information
- Network health monitoring

#### Logs
- Real-time log viewing
- Filtering by log level and search terms
- Export logs in various formats

#### Throttle
- Adjust CPU, GPU, and memory limits
- Performance presets (Performance, Balanced, Power Saving)
- Real-time throttling controls

#### Settings
- Comprehensive configuration management
- Tabbed interface for different setting categories
- Save and apply configuration changes

## Troubleshooting

### Common Issues

#### Service Won't Start
1. Check logs: `tail -f /var/log/exo/exo.log`
2. Verify installation: `./scripts/check_exo_status.sh`
3. Check permissions: Ensure scripts are executable
4. Verify dependencies: Python, Git, etc.

#### Network Discovery Issues
1. Check firewall settings for UDP port 52415
2. Verify network connectivity between nodes
3. Review discovery module configuration

#### Performance Issues
1. Adjust GPU memory fraction in settings
2. Monitor system resources in Performance tab
3. Use throttling controls to limit resource usage

#### ExoManager Build Issues
1. Ensure Xcode command line tools are installed
2. Check macOS version compatibility
3. Verify all source files are present

### Getting Help

1. **Check the logs**: Use the Logs tab in ExoManager or view `/var/log/exo/exo.log`
2. **Review configuration**: Verify settings in the Settings tab
3. **Check system status**: Use the Dashboard for an overview
4. **Consult documentation**: Review Exo documentation at https://github.com/exo-explore/exo

## Development

### Building ExoManager

```bash
# Install dependencies
xcode-select --install

# Build the app
./build.sh

# Development build (for testing)
xcodebuild -project ExoManager.xcodeproj -scheme ExoManager -configuration Debug build
```

### Project Structure

```
exo-cluster-scripts/
├── scripts/                    # Shell scripts for Exo management
│   ├── install_exo_service.sh
│   ├── uninstall_exo_service.sh
│   ├── start_exo.sh
│   ├── check_exo_status.sh
│   └── exo_config_example.sh
├── ExoManager/                 # macOS app source code
│   ├── ExoManagerApp.swift     # App entry point
│   ├── ContentView.swift       # Main content view
│   ├── Models/                 # Data models and managers
│   ├── Views/                  # SwiftUI views
│   ├── Assets.xcassets/        # App assets
│   └── Info.plist             # App configuration
├── ExoManager.xcodeproj/       # Xcode project
├── build.sh                   # Build script
└── README.md                  # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Exo AI](https://github.com/exo-explore/exo) - The AI cluster server
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern UI framework
- [Network Framework](https://developer.apple.com/documentation/network) - Network discovery
