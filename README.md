# exo-cluster-scripts

Automated installation scripts for running [exo](https://github.com/exo-explore/exo) LLM cluster on macOS. This repository provides a **self-contained installation** that automatically handles Python version compatibility and system configuration.

## What is exo?

[exo](https://github.com/exo-explore/exo) is an open-source framework that allows you to run your own AI cluster at home using everyday devices. It enables distributed inference across multiple machines, turning your devices into one powerful AI cluster.

Key features:
- **Device Equality**: P2P architecture without master-worker hierarchy
- **Heterogeneous Support**: Works across different device types (Mac, Linux, etc.)
- **Multiple Inference Engines**: Supports MLX, tinygrad, and more
- **Automatic Discovery**: Devices automatically find each other on the network
- **Web UI**: Built-in ChatGPT-like interface at `http://localhost:52415`
- **API Compatible**: ChatGPT-compatible API endpoint

## 🚀 Quick Start (Recommended)

### One-Command Installation

The easiest way to install exo:

```bash
git clone https://github.com/stevenmoon/exo-cluster-scripts.git
cd exo-cluster-scripts
./install_exo_auto.sh
```

This automated script:
- ✅ Automatically detects or installs Python 3.10+ via Homebrew
- ✅ Sets up isolated Python environment (no system conflicts)
- ✅ Installs exo as a system service that starts on boot
- ✅ Works on both Apple Silicon and Intel Macs
- ✅ Handles all dependencies automatically

## Manual Installation

If you prefer step-by-step control:

1. **Setup Python environment:**
   ```bash
   ./scripts/setup_python_env.sh
   source /tmp/exo_python_env
   ```

2. **Install exo service:**
   ```bash
   sudo -E ./scripts/install_exo_service.sh
   ```

## Prerequisites

- **macOS 10.15+** (Catalina or later)
- **Python 3.10+** (automatically installed if missing)
- **Homebrew** (automatically installed if missing)
- **8GB+ RAM** (16GB+ recommended for larger models)
- **10GB+ free disk space** for models
- **Network access** for downloading models and device discovery

## What Gets Installed

The installation process:

1. **Python Environment**: Isolated Python 3.12 via Homebrew
2. **exo Repository**: Clones from `https://github.com/exo-explore/exo.git`
3. **Virtual Environment**: Creates `/opt/exo/venv` with all dependencies
4. **System Service**: LaunchDaemon for automatic startup
5. **Command-line Tools**: 
   - `exo` - Main exo command
   - `exo-status` - Status checker

## Usage

### Basic Usage

Once installed, exo runs automatically on boot. Access:

- **Web Interface**: http://localhost:52415
- **API Endpoint**: http://localhost:52415/v1/chat/completions

### Status & Management

```bash
# Check status
exo-status              # Quick status
exo-status full         # Detailed status

# Manage service
sudo launchctl start com.exolabs.exo
sudo launchctl stop com.exolabs.exo
sudo launchctl restart com.exolabs.exo

# View logs
tail -f /var/log/exo/exo.log
```

### API Examples

```bash
# Chat completion
curl http://localhost:52415/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
     "model": "llama-3.2-3b",
     "messages": [{"role": "user", "content": "Hello!"}],
     "temperature": 0.7
   }'
```

## Multi-Device Cluster Setup

To create a cluster across multiple devices:

1. **Install on each device** using the same process
2. **Ensure devices are on the same network**
3. **exo automatically discovers** other devices
4. **Access any device's web interface** to use the entire cluster

Example: MacBook Air M3 (8GB) + Mac Mini M2 (16GB) + Linux server (32GB) = 56GB total cluster memory

## Configuration

### Custom Configuration

```bash
# Copy example config
cp scripts/exo_config_example.sh /opt/exo/scripts/exo_config.sh

# Edit configuration  
nano /opt/exo/scripts/exo_config.sh

# Restart service
sudo launchctl restart com.exolabs.exo
```

### Common Configuration Options

- **Model Storage**: `EXO_HOME` (default: `/opt/exo/.cache/exo`)
- **Discovery Method**: `EXO_DISCOVERY_MODULE` (udp, manual, tailscale)
- **Web Interface**: `EXO_WEB_PORT` and `EXO_WEB_HOST`
- **GPU Memory**: `EXO_GPU_MEMORY_FRACTION`
- **Debug Logging**: `DEBUG` level (0-9)

## Troubleshooting

### Installation Issues

```bash
# Check system requirements
./scripts/setup_python_env.sh

# Check service status
exo-status full

# View installation logs
tail -f /var/log/exo/exo.log
```

### Common Solutions

**Service not starting:**
```bash
sudo launchctl unload /Library/LaunchDaemons/com.exolabs.exo.plist
sudo launchctl load /Library/LaunchDaemons/com.exolabs.exo.plist
```

**Python issues:**
```bash
# Reinstall Python
brew install python@3.12
```

**Port conflicts:**
```bash
# Check what's using port 52415
lsof -i :52415
```

## Uninstall

```bash
sudo ./scripts/uninstall_exo_service.sh
```

This removes:
- exo service and configuration
- Installation directory `/opt/exo`
- System commands (`exo`, `exo-status`)
- Log files

## File Structure

```
exo-cluster-scripts/
├── install_exo_auto.sh              # One-command installation
├── scripts/
│   ├── setup_python_env.sh         # Python environment setup
│   ├── install_exo_service.sh      # Main installation script
│   ├── start_exo.sh                # Service startup script
│   ├── check_exo_status.sh         # Status checker (simplified)
│   ├── uninstall_exo_service.sh    # Clean removal
│   ├── com.exolabs.exo.plist       # LaunchDaemon configuration
│   └── exo_config_example.sh       # Configuration template
└── README.md                        # This documentation
```

## Performance Tips

- **Apple Silicon**: MLX automatically configured for optimal performance
- **Memory**: 16GB+ recommended for larger models
- **Network**: Wired connection preferred for multi-device clusters
- **Storage**: SSD recommended for model loading speed

## Security Notes

- Service runs as `root` for system-wide installation
- Installation isolated in `/opt/exo/`
- Logs stored in `/var/log/exo/`
- Web interface binds to `0.0.0.0` by default (configurable)

## Support & Links

- **Installation Issues**: [GitHub Issues](https://github.com/stevenmoon/exo-cluster-scripts/issues)
- **exo Framework**: [GitHub](https://github.com/exo-explore/exo)
- **Community**: [Discord](https://discord.gg/exo)

## License

GPL-3.0 (same as exo framework)
