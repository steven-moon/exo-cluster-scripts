# ExoManager - macOS App for exo Cluster Management

A native macOS application for managing [exo](https://github.com/exo-explore/exo) AI clusters with comprehensive monitoring, throttling controls, and network discovery.

## Features

### 🚀 **Service Management**
- **One-click Installation/Uninstallation** - Install exo as a system service with automatic startup
- **Service Control** - Start, stop, restart exo service with visual status indicators
- **Automatic Configuration** - Generate and apply exo configuration files

### 📊 **Real-time Monitoring**
- **System Resources** - Live CPU, Memory, GPU, and Disk usage monitoring
- **Performance Charts** - Interactive charts with multiple time ranges (5min to 6 hours)
- **Process Information** - Detailed exo process monitoring with PID, memory usage, and command details
- **Network Status** - Web interface and API endpoint accessibility monitoring

### 🎛️ **Advanced Throttling**
- **Resource Limits** - Set maximum CPU, Memory, and GPU usage limits
- **Adaptive Throttling** - Automatic resource management to prevent system overload
- **Performance Presets** - Quick configuration for different use cases:
  - **Performance** - Maximum performance with high resource usage
  - **Balanced** - Good performance with moderate resource usage
  - **Conservative** - Lower performance with minimal resource usage
  - **Development** - Debug mode with detailed logging

### 🌐 **Network Discovery**
- **Automatic Discovery** - Find other exo nodes on your network
- **Cluster Management** - View cluster information and capabilities
- **Node Details** - Detailed information about discovered nodes
- **Direct Connection** - Connect to any node's web interface directly from the app

### 💬 **Embedded Chat Interface**
- **Built-in Web View** - Access the exo chat interface without opening a browser
- **Real-time Updates** - Automatic refresh and status monitoring
- **Error Handling** - Graceful handling of connection issues

### 📝 **Log Management**
- **Real-time Logs** - Live log monitoring with automatic updates
- **Advanced Filtering** - Filter by log level, search text, and error status
- **Log Export** - Export filtered logs to files
- **Log Statistics** - View log statistics and error rates

### ⚙️ **Comprehensive Settings**
- **Basic Configuration** - Model storage, HF endpoint, web interface settings
- **Network Settings** - Discovery modules, Tailscale integration, manual peer configuration
- **Performance Tuning** - GPU memory fraction, model cache size, debug levels
- **Advanced Options** - Logging configuration, security settings, custom arguments

## Installation

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later (for building)
- exo-cluster-scripts repository (for service installation)

### Building the App

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd exo-cluster-scripts/ExoManager
   ```

2. **Open in Xcode**
   ```bash
   open ExoManager.xcodeproj
   ```

3. **Build and Run**
   - Select your target device (Mac)
   - Press Cmd+R to build and run
   - Or select Product → Build to create the app bundle

### Distribution

The app can be distributed as:
- **Development Build** - For testing and development
- **App Store Distribution** - Through the Mac App Store (requires code signing)
- **Direct Distribution** - As a standalone .app bundle

## Usage

### First Launch
1. **Install exo Service** - Click "Install Exo Service" in the Quick Actions section
2. **Start Service** - Use the Start button in the header to launch exo
3. **Configure Settings** - Adjust throttling and performance settings as needed

### Dashboard
The main dashboard provides:
- **Service Status** - Current state of the exo service
- **System Resources** - Real-time resource usage
- **Network Discovery** - Discovered exo nodes
- **Quick Actions** - Common tasks and shortcuts

### Performance Monitoring
- **Real-time Charts** - Interactive performance graphs
- **Resource Limits** - Visual indicators for throttling limits
- **Process Details** - Detailed exo process information
- **Historical Data** - Performance history with multiple time ranges

### Network Management
- **Node Discovery** - Automatic discovery of exo nodes
- **Cluster Overview** - Total cluster resources and capabilities
- **Node Details** - Individual node information and actions
- **Direct Connection** - Connect to node web interfaces

### Settings Configuration
- **Basic Settings** - Model storage, web interface configuration
- **Network Settings** - Discovery modules and peer configuration
- **Performance Settings** - GPU memory, cache size, debug levels
- **Advanced Settings** - Logging, security, custom arguments

## Architecture

### Core Components

#### ExoServiceManager
- Manages exo service installation, uninstallation, and control
- Handles configuration file generation and updates
- Provides service status monitoring

#### ExoMonitor
- Real-time system resource monitoring
- Performance data collection and history
- Log file monitoring and parsing
- Network connectivity testing

#### ExoNetworkDiscovery
- UDP-based network discovery
- Node information collection and management
- Cluster information aggregation
- Network scanning and peer detection

#### ExoSettings
- Comprehensive settings management
- Configuration persistence
- Settings validation and presets
- Integration with service manager

### UI Components

#### ContentView
- Main application interface with tabbed navigation
- Dashboard with status cards and quick actions
- Service control buttons and status indicators

#### ExoPerformanceView
- Interactive performance charts using Swift Charts
- Real-time metric display
- Multiple time range support
- Process information display

#### ExoNetworkView
- Network discovery interface
- Node list and details
- Cluster information display
- Connection management

#### ExoLogViewer
- Real-time log display
- Advanced filtering and search
- Log export functionality
- Log statistics and analysis

#### ExoThrottleView
- Resource limit controls
- Performance preset management
- Real-time throttling status
- Advanced throttling options

#### ExoSettingsView
- Comprehensive settings interface
- Tabbed configuration sections
- Settings validation and presets
- Configuration management

## Configuration

### Service Integration
The app integrates with the exo-cluster-scripts repository:
- Uses existing installation scripts
- Generates configuration files
- Manages service lifecycle
- Provides status monitoring

### Network Discovery
- **UDP Discovery** - Broadcast-based node discovery
- **Manual Configuration** - Static peer configuration
- **Tailscale Integration** - Tailscale-based discovery
- **Network Scanning** - Active network scanning

### Performance Monitoring
- **System Metrics** - CPU, Memory, GPU, Disk usage
- **Process Monitoring** - exo process details
- **Network Status** - Web interface and API accessibility
- **Historical Data** - Performance history and trends

## Security Considerations

### Permissions
- **Administrator Access** - Required for service installation
- **Network Access** - Required for discovery and monitoring
- **File System Access** - Required for log monitoring and configuration

### Data Handling
- **Local Storage** - Settings stored in UserDefaults
- **Network Communication** - Secure communication with exo services
- **Log Data** - Log files accessed with appropriate permissions

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
1. Adjust throttling settings
2. Check system resource usage
3. Verify GPU memory allocation
4. Review log files for errors

#### ExoManager Build Issues
1. Ensure Xcode command line tools are installed
2. Check macOS version compatibility
3. Verify all source files are present

#### Privilege Escalation Issues
If the app freezes during installation or you get permission errors:

1. **Run the app with administrator privileges:**
   ```bash
   sudo open /Applications/ExoManager.app
   ```

2. **Or grant the app administrator privileges:**
   - Right-click on ExoManager.app in Finder
   - Select "Get Info"
   - Check "Run as administrator"

3. **Alternative: Install exo manually first:**
   ```bash
   cd /path/to/exo-cluster-scripts
   sudo ./scripts/install_exo_service.sh
   ```
   Then use ExoManager to manage the service.

4. **Check if scripts are included in app bundle:**
   ```bash
   ls -la /Applications/ExoManager.app/Contents/Resources/scripts/
   ```

5. **Verify sudo access:**
   ```bash
   sudo whoami
   ```
   Should return "root"

#### App Freezes During Installation
1. The installation process can take several minutes
2. Check the progress indicator in the app
3. If it freezes for more than 5 minutes, force quit and try again
4. Ensure you have a stable internet connection (for downloading exo)
5. Check available disk space (at least 5GB recommended)

### Getting Help

1. **Check the logs**: Use the Logs tab in ExoManager or view `/var/log/exo/exo.log`
2. **Review configuration**: Verify settings in the Settings tab
3. **Check system status**: Use the Dashboard for an overview
4. **Consult documentation**: Review Exo documentation at https://github.com/exo-explore/exo

## Development

### Project Structure
```
ExoManager/
├── ExoManager/
│   ├── ExoManagerApp.swift          # Main app entry point
│   ├── ContentView.swift            # Main interface
│   ├── ExoServiceManager.swift      # Service management
│   ├── ExoMonitor.swift             # Monitoring system
│   ├── ExoNetworkDiscovery.swift    # Network discovery
│   ├── ExoSettings.swift            # Settings management
│   ├── ExoWebView.swift             # Web view component
│   ├── ExoPerformanceView.swift     # Performance monitoring
│   ├── ExoLogViewer.swift           # Log management
│   ├── ExoThrottleView.swift        # Throttling controls
│   ├── ExoSettingsView.swift        # Settings interface
│   ├── ExoNetworkView.swift         # Network management
│   ├── Assets.xcassets/             # App assets
│   ├── Info.plist                   # App configuration
│   └── Preview Content/             # Preview assets
└── ExoManager.xcodeproj/            # Xcode project
```

### Building from Source
1. Ensure Xcode 15.0+ is installed
2. Clone the repository
3. Open ExoManager.xcodeproj in Xcode
4. Select target device (Mac)
5. Build and run (Cmd+R)

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the same license as exo (GPL-3.0).

## Support

For issues related to:
- **ExoManager App** - Open an issue on this repository
- **exo Framework** - Open an issue on the [exo repository](https://github.com/exo-explore/exo)
- **exo-cluster-scripts** - Open an issue on the scripts repository

## Acknowledgments

- [exo](https://github.com/exo-explore/exo) - The AI cluster framework
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [Swift Charts](https://developer.apple.com/documentation/charts) - Charting framework
- [Network Framework](https://developer.apple.com/documentation/network) - Network discovery 