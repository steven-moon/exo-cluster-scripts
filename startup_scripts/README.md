# exo Startup Service for macOS

This directory contains scripts to install exo as a system-wide service that automatically starts when your Mac boots up, even without a logged-in user.

## Prerequisites

1. **Install exo first**: Make sure you have exo installed on your system
   ```bash
   git clone https://github.com/exo-explore/exo.git
   cd exo
   pip install -e .
   ```

2. **Python 3.12+**: Ensure Python 3.12 or later is installed
   ```bash
   python3 --version
   ```

## Installation

1. **Navigate to the startup_scripts directory**:
   ```bash
   cd startup_scripts
   ```

2. **Run the installation script as root**:
   ```bash
   sudo ./install_exo_service.sh
   ```

3. **Verify the installation**:
   ```bash
   sudo launchctl list | grep exo
   ```

## How it works

- The service runs as a **LaunchDaemon** (system-wide service)
- It starts automatically when the system boots
- Runs under the `root` user with `wheel` group permissions
- Logs are stored in `/var/log/exo/`
- The service will automatically restart if exo crashes

## Service Management

### Check service status:
```bash
sudo launchctl list | grep exo
```

### Start the service manually:
```bash
sudo launchctl start com.exolabs.exo
```

### Stop the service:
```bash
sudo launchctl stop com.exolabs.exo
```

### View logs:
```bash
tail -f /var/log/exo/exo.log
```

### View launchd logs:
```bash
tail -f /var/log/exo/launchd.log
tail -f /var/log/exo/launchd_error.log
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
nohup exo --discovery-module tailscale --tailscale-api-key YOUR_KEY > "$LOG_FILE" 2>&1 &

# Set custom model storage location
export EXO_HOME="/Users/shared/exo_cache"

# Add custom environment variables
export DEBUG=1
export TINYGRAD_DEBUG=2
```

## Uninstallation

To completely remove the startup service:

```bash
sudo ./uninstall_exo_service.sh
```

## Troubleshooting

### Service won't start

1. **Check launchd logs**:
   ```bash
   tail -f /var/log/exo/launchd_error.log
   ```

2. **Check exo logs**:
   ```bash
   tail -f /var/log/exo/exo.log
   ```

3. **Verify exo is installed**:
   ```bash
   which exo
   exo --help
   ```

4. **Check file permissions**:
   ```bash
   ls -la /opt/exo/startup_scripts/
   ls -la /Library/LaunchDaemons/com.exolabs.exo.plist
   ```

### Common issues

1. **Python path issues**: Make sure exo is in the system PATH
2. **Permission issues**: Ensure the service has proper permissions
3. **Port conflicts**: Check if port 52415 is already in use
4. **Network issues**: Ensure the device can access the internet for model downloads

### Manual testing

Test the startup script manually before installing as a service:

```bash
sudo /opt/exo/startup_scripts/start_exo.sh start
sudo /opt/exo/startup_scripts/start_exo.sh status
sudo /opt/exo/startup_scripts/start_exo.sh stop
```

## Security Considerations

- The service runs as `root` for system-wide access
- Logs are stored in `/var/log/exo/` with appropriate permissions
- The service only starts the exo process, no additional network services
- Consider firewall rules if needed for your specific use case

## Support

For issues with the startup service, check the logs first. For exo-specific issues, refer to the main exo documentation and GitHub repository.

## Files Overview

- **`start_exo.sh`**: Main startup script that handles starting/stopping exo
- **`com.exolabs.exo.plist`**: LaunchDaemon configuration file for macOS
- **`install_exo_service.sh`**: Installation script to set up the service
- **`uninstall_exo_service.sh`**: Uninstallation script to remove the service
- **`README.md`**: This documentation file 