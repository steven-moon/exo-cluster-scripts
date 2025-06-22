# exo-cluster-scripts

Automated startup scripts for running [exo](https://github.com/exo-explore/exo) LLM cluster on macOS. This repository provides scripts to install and configure exo as a system service that automatically starts on boot.

## What is exo?

[exo](https://github.com/exo-explore/exo) is an open-source framework that allows you to run your own AI cluster at home using everyday devices. It unifies your existing devices into one powerful GPU, enabling distributed inference across multiple machines.

Key features:
- **Device Equality**: P2P architecture without master-worker hierarchy
- **Heterogeneous Support**: Works across different device types (Mac, Linux, etc.)
- **Multiple Inference Engines**: Supports MLX, tinygrad, and more
- **Automatic Discovery**: Devices automatically find each other on the network
- **Web UI**: Built-in ChatGPT-like interface at `http://localhost:52415`
- **API Compatible**: ChatGPT-compatible API endpoint

## Repository Structure

```
exo-cluster-scripts/
├── README.md                           # This comprehensive documentation
├── test_installation.sh                # Test script to verify installation
└── startup_scripts/
    ├── install_exo_service.sh          # Install exo as system service
    ├── uninstall_exo_service.sh        # Remove exo service
    ├── start_exo.sh                    # Main startup script
    ├── com.exolabs.exo.plist           # LaunchDaemon configuration
    └── exo_config_example.sh           # Example configuration file
```

## Prerequisites

- **macOS**: Tested on macOS 14+ (Sequoia recommended for best performance)
- **Python 3.12+**: Required for exo compatibility
- **Root Access**: Required for system service installation
- **Network Access**: For downloading models and device discovery

## Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/your-username/exo-cluster-scripts.git
cd exo-cluster-scripts
```

### 2. Test the installation (recommended)

```bash
./test_installation.sh
```

This script will verify all prerequisites and check that the startup scripts are ready for installation.

### 3. Install exo as a system service

```bash
sudo ./startup_scripts/install_exo_service.sh
```

This script will:
- Clone the exo repository from GitHub
- Configure MLX for optimal performance on Apple Silicon
- Update MLX to version 0.26.1 (fixes compatibility issues)
- Create a local Python virtual environment
- Install exo in the virtual environment (avoids system conflicts)
- Set up exo as a LaunchDaemon that starts on boot

### 4. Verify installation

```bash
# Check service status
sudo launchctl list | grep exo

# View logs
tail -f /var/log/exo/exo.log

# Test the web interface
open http://localhost:52415
```

## Installation Details

The installation process includes:

1. **Repository Cloning**: Clones exo from `https://github.com/exo-explore/exo.git`
2. **MLX Configuration**: Runs `configure_mlx.sh` for Apple Silicon optimization
3. **MLX Version Update**: Updates MLX from 0.22.0 to 0.26.1 in `setup.py`
4. **Virtual Environment**: Creates `/opt/exo/venv` for isolated Python environment
5. **exo Installation**: Installs exo in development mode within the virtual environment
6. **Service Setup**: Configures LaunchDaemon for automatic startup

### Virtual Environment Benefits

- **Isolated Dependencies**: No conflicts with existing Python packages
- **System Compatibility**: Works on all macOS systems regardless of Python setup
- **Easy Management**: All exo dependencies are contained in `/opt/exo/venv`
- **Clean Uninstall**: Removing `/opt/exo` completely removes exo and all dependencies

## Service Management

### Start/Stop the service

```bash
# Start exo service
sudo launchctl start com.exolabs.exo

# Stop exo service
sudo launchctl stop com.exolabs.exo

# Restart exo service
sudo launchctl stop com.exolabs.exo
sudo launchctl start com.exolabs.exo
```

### Check service status

```bash
# Check if service is loaded
sudo launchctl list | grep exo

# Check if exo process is running
ps aux | grep exo

# View real-time logs
tail -f /var/log/exo/exo.log
```

### Uninstall the service

```bash
sudo ./startup_scripts/uninstall_exo_service.sh
```

## Configuration

### Customizing the startup script

You can modify `/opt/exo/startup_scripts/start_exo.sh` to:

- Change the exo home directory: Set `EXO_HOME` environment variable
- Add custom command line arguments to exo
- Modify logging behavior
- Add custom environment variables

### Example customizations:

```bash
# In start_exo.sh, modify the start_exo() function:

# Add custom exo arguments
"$exo_executable" --discovery-module tailscale --tailscale-api-key YOUR_KEY > "$LOG_FILE" 2>&1 &

# Set custom model storage location
export EXO_HOME="/Users/shared/exo_cache"

# Add custom environment variables
export DEBUG=1
export TINYGRAD_DEBUG=2
```

### Environment Variables

You can set these environment variables in the startup script:

- `EXO_HOME`: Model storage location (default: `/opt/exo/.cache/exo`)
- `HF_ENDPOINT`: Hugging Face mirror for restricted regions
- `DEBUG`: Debug logging level (0-9)
- `TINYGRAD_DEBUG`: tinygrad debug level (1-6)

### Configuration File

Copy and modify the example configuration:

```bash
cp startup_scripts/exo_config_example.sh /opt/exo/startup_scripts/exo_config.sh
# Edit the configuration file as needed
```

## Usage

Once installed, exo will automatically start when your Mac boots up. You can access:

- **Web Interface**: http://localhost:52415
- **API Endpoint**: http://localhost:52415/v1/chat/completions

### Example API Usage

```bash
# Test with Llama 3.2 3B
curl http://localhost:52415/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
     "model": "llama-3.2-3b",
     "messages": [{"role": "user", "content": "Hello, how are you?"}],
     "temperature": 0.7
   }'

# Test with vision model (Llava 1.5)
curl http://localhost:52415/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
     "model": "llava-1.5-7b-hf",
     "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "What are these?"},
          {"type": "image_url", "image_url": {"url": "http://example.com/image.jpg"}}
        ]
      }
    ],
     "temperature": 0.0
   }'
```

## Multi-Device Setup

To create a cluster across multiple devices:

1. **Install on each device** using the same installation process
2. **Ensure devices are on the same network**
3. **Start exo on each device** - they will automatically discover each other
4. **Access any device's web interface** to use the entire cluster

### Example Multi-Device Configuration

- **Device 1 (MacBook Air M3)**: 8GB memory
- **Device 2 (Mac Mini M2)**: 16GB memory
- **Device 3 (Linux Server)**: 32GB memory + NVIDIA GPU

Total cluster memory: 56GB (can run large models like Llama 3.1 405B)

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check logs for errors
   tail -f /var/log/exo/exo.log
   
   # Verify Python version
   python3 --version  # Should be 3.12+
   ```

2. **MLX configuration issues**
   ```bash
   # Re-run MLX configuration
   cd /opt/exo
   ./configure_mlx.sh
   ```

3. **Model download issues**
   ```bash
   # Check network connectivity
   curl -I https://huggingface.co
   
   # Use proxy if needed
   export HF_ENDPOINT=https://hf-mirror.com
   ```

4. **Permission issues**
   ```bash
   # Fix permissions
   sudo chown -R root:wheel /opt/exo
   sudo chmod -R 755 /opt/exo
   ```

### Debug Mode

Enable debug logging:

```bash
# For exo debugging
export DEBUG=9
sudo launchctl stop com.exolabs.exo
sudo launchctl start com.exolabs.exo

# For tinygrad debugging (if using tinygrad engine)
export TINYGRAD_DEBUG=2
```

### Manual testing

Test the startup script manually before installing as a service:

```bash
sudo /opt/exo/startup_scripts/start_exo.sh start
sudo /opt/exo/startup_scripts/start_exo.sh status
sudo /opt/exo/startup_scripts/start_exo.sh stop
```

## Performance Optimization

For best performance on Apple Silicon Macs:

1. **Upgrade to macOS Sequoia** (latest version)
2. **Run MLX configuration** (done automatically during installation)
3. **Ensure adequate cooling** for sustained GPU usage
4. **Use wired network** for multi-device clusters

## Security Considerations

- The service runs as `root` for system-wide access
- Logs are stored in `/var/log/exo/` with appropriate permissions
- The service only starts the exo process, no additional network services
- Consider firewall rules if needed for your specific use case
- exo installation is isolated in `/opt/exo/`

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the same license as exo (GPL-3.0).

## Links

- [exo GitHub Repository](https://github.com/exo-explore/exo)
- [exo Documentation](https://github.com/exo-explore/exo#readme)
- [exo Discord](https://discord.gg/exo)
- [exo Telegram](https://t.me/exo_ai)

## Support

For issues related to:
- **This repository**: Open an issue on this GitHub repository
- **exo framework**: Open an issue on the [exo repository](https://github.com/exo-explore/exo)
- **Community support**: Join the [exo Discord](https://discord.gg/exo) or [Telegram](https://t.me/exo_ai)
