# exo-cluster-scripts

Automated installation scripts for running [exo](https://github.com/exo-explore/exo) LLM cluster on macOS. This repository provides a **self-contained installation** that automatically handles Python version compatibility and system configuration.

## What is exo?

[exo](https://github.com/exo-explore/exo) is an open-source framework that allows you to run your own AI cluster at home using everyday devices. It unifies your existing devices into one powerful GPU, enabling distributed inference across multiple machines.

Key features:
- **Device Equality**: P2P architecture without master-worker hierarchy
- **Heterogeneous Support**: Works across different device types (Mac, Linux, etc.)
- **Multiple Inference Engines**: Supports MLX, tinygrad, and more
- **Automatic Discovery**: Devices automatically find each other on the network
- **Web UI**: Built-in ChatGPT-like interface at `http://localhost:52415`
- **API Compatible**: ChatGPT-compatible API endpoint

## 🚀 Quick Start (Recommended)

### Automated Installation

The easiest way to install exo with automatic Python setup:

```bash
git clone https://github.com/your-username/exo-cluster-scripts.git
cd exo-cluster-scripts
./install_exo_auto.sh
```

This automated script:
- ✅ Automatically detects or installs Python 3.10+ via Homebrew
- ✅ Sets up the correct Python environment without conflicting with system Python
- ✅ Installs exo as a system service that starts on boot
- ✅ Works on both Apple Silicon and Intel Macs

### Test First (Optional)

To verify your system is ready:

```bash
./test_installation.sh
```

## Manual Installation

If you prefer manual control:

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

- **macOS 14+** (Sequoia recommended for best performance)
- **Python 3.10+** (automatically installed if missing)
- **Homebrew** (automatically installed if missing)
- **Network Access** for downloading models and device discovery

## What Gets Installed

The installation process:

1. **Python Environment**: Installs Python 3.12 via Homebrew (isolated from system Python)
2. **exo Repository**: Clones from `https://github.com/exo-explore/exo.git`
3. **Virtual Environment**: Creates `/opt/exo/venv` with all dependencies
4. **MLX Optimization**: Configures MLX 0.26.1 for Apple Silicon performance
5. **System Service**: Sets up LaunchDaemon for automatic startup
6. **Command-line Tools**: 
   - `exo` command available system-wide
   - `exo-status` for checking service status

## Usage

Once installed, exo runs automatically on boot. Access:

- **Web Interface**: http://localhost:52415
- **API Endpoint**: http://localhost:52415/v1/chat/completions

### Service Management

```bash
# Check status
exo-status              # Detailed status report
exo-status quick        # Quick summary

# Manage service
sudo launchctl start com.exolabs.exo
sudo launchctl stop com.exolabs.exo

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

# Vision model
curl http://localhost:52415/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
     "model": "llava-1.5-7b-hf", 
     "messages": [
       {
         "role": "user",
         "content": [
           {"type": "text", "text": "What's in this image?"},
           {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}
         ]
       }
     ]
   }'
```

## Multi-Device Cluster Setup

To create a cluster across multiple devices:

1. **Install on each device** using the same process
2. **Ensure devices are on the same network**
3. **exo will automatically discover** other devices
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

### Configuration Options

- **Model Storage**: `EXO_HOME` (default: `/opt/exo/.cache/exo`)
- **Discovery Module**: `EXO_DISCOVERY_MODULE` (udp, manual, tailscale)
- **Web Interface**: `EXO_WEB_PORT` and `EXO_WEB_HOST`
- **GPU Memory**: `EXO_GPU_MEMORY_FRACTION`
- **Debug Logging**: `DEBUG` level (0-9)

## Troubleshooting

### Python Version Issues

The installation automatically handles Python compatibility, but if you see errors:

```bash
# Check what Python will be used
./scripts/setup_python_env.sh

# Manually install Python if needed
brew install python@3.12
```

### Service Issues

```bash
# Check detailed status
exo-status

# View real-time logs
tail -f /var/log/exo/exo.log

# Restart service
sudo launchctl stop com.exolabs.exo
sudo launchctl start com.exolabs.exo
```

### Network Issues

```bash
# Test connectivity
curl -I https://github.com
curl -I https://pypi.org

# Check if port is available
lsof -i :52415
```

### MLX Issues (Apple Silicon)

```bash
# Re-run MLX configuration
cd /opt/exo
./configure_mlx.sh
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

## Advanced Features

### Self-Contained Installation

This installation is designed to be completely self-contained:

- **No System Python Conflicts**: Uses isolated Homebrew Python
- **Automatic Dependency Management**: Handles all Python dependencies in virtual environment
- **Robust Error Handling**: Clear error messages and recovery suggestions
- **Cross-Platform Support**: Works on Apple Silicon and Intel Macs

### File Structure

```
exo-cluster-scripts/
├── install_exo_auto.sh              # One-command automated installation
├── test_installation.sh             # Pre-installation verification
├── scripts/
│   ├── setup_python_env.sh         # Python environment setup
│   ├── install_exo_service.sh      # Main installation script
│   ├── start_exo.sh                # Service startup script
│   ├── check_exo_status.sh         # Status monitoring
│   ├── uninstall_exo_service.sh    # Clean removal
│   ├── com.exolabs.exo.plist       # LaunchDaemon configuration
│   └── exo_config_example.sh       # Configuration template
└── README.md                        # This documentation
```

## Performance Optimization

For best performance:

1. **macOS Sequoia**: Latest version recommended
2. **Adequate Memory**: 8GB+ recommended, 16GB+ for larger models  
3. **SSD Storage**: 10GB+ free space for models
4. **Wired Network**: For multi-device clusters
5. **Proper Cooling**: For sustained GPU usage

## Security Notes

- Service runs as `root` for system-wide access
- Installation is isolated in `/opt/exo/`
- Logs stored in `/var/log/exo/` with appropriate permissions
- Only starts exo process, no additional network services

## Support & Links

- **This Repository Issues**: For installation script problems
- **exo Framework**: [GitHub](https://github.com/exo-explore/exo) | [Issues](https://github.com/exo-explore/exo/issues)
- **Community**: [Discord](https://discord.gg/exo) | [Telegram](https://t.me/exo_ai)

## License

GPL-3.0 (same as exo framework)
