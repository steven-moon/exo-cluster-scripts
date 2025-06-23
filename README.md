# exo-cluster-scripts

Automated startup scripts for running the [exo](https://github.com/exo-explore/exo) LLM cluster on macOS. This repository provides a single script to install and configure exo as a system service that automatically starts on boot.

## What is exo?

[exo](https://github.com/exo-explore/exo) is an open-source framework that allows you to run your own AI cluster at home using everyday devices. It unifies your existing devices into one powerful GPU, enabling distributed inference across multiple machines.

Key features:
- **Device Equality**: P2P architecture without a master-worker hierarchy.
- **Heterogeneous Support**: Works across different device types (Mac, Linux, etc.).
- **Multiple Inference Engines**: Supports MLX, tinygrad, and more.
- **Automatic Discovery**: Devices automatically find each other on the network.
- **Web UI**: Built-in ChatGPT-like interface at `http://localhost:52415`.
- **API Compatible**: Offers a ChatGPT-compatible API endpoint for integration.

## Prerequisites

- **macOS**: Tested on macOS 14+ (Sonoma or later).
- **Python 3.10+**: The installer can automatically install Python using Homebrew if needed.
- **Root Access**: Required for system service installation. `sudo` will be requested.
- **Network Access**: For downloading the exo repository and required models.
- **Git & Curl**: Standard command-line tools that should be pre-installed on macOS.

## Quick Start

The installation has been streamlined into a single script.

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/exo-explore/exo-cluster-scripts.git
    cd exo-cluster-scripts
    ```

2.  **Run the automated installer:**
    ```bash
    ./install_exo_auto.sh
    ```

This script will handle everything:
- It checks for a compatible Python version and offers to install it with Homebrew if one isn't found.
- It asks for `sudo` permission upfront.
- It clones the `exo` repository into `/opt/exo`.
- It creates a self-contained Python virtual environment.
- It installs `exo` and its dependencies.
- It configures `exo` as a `launchd` service to run automatically on system boot.
- It creates system-wide commands (`exo` and `exo-status`) for easy access.

## Repository Structure

```
exo-cluster-scripts/
├── README.md                     # This documentation
├── install_exo_auto.sh           # Single, automated installation script
├── validate_project.sh           # Script to validate the project setup
└── scripts/
    ├── utils.sh                  # Shared utility functions for scripts
    ├── start_exo.sh              # Startup script run by the system service
    ├── check_exo_status.sh       # Powers the 'exo-status' command
    ├── uninstall_exo_service.sh  # Removes the exo service and all files
    ├── com.exolabs.exo.plist     # launchd service configuration
    └── exo_config_example.sh     # Example configuration file
```

## Service Management

You can manage the `exo` service using the standard `launchctl` commands or the provided `exo-status` helper.

### Check Service Status

The easiest way to check on `exo` is with the `exo-status` command.

```bash
# Quick status summary
exo-status

# Detailed status report
exo-status full
```

The status command provides comprehensive information, including:
- Installation and service status (loaded/running).
- Process information and resource usage.
- Web interface accessibility.
- Recent log entries and errors.

### Start, Stop, and Restart

```bash
# Start the service
sudo launchctl start com.exolabs.exo

# Stop the service
sudo launchctl stop com.exolabs.exo

# Restart the service
sudo launchctl stop com.exolabs.exo && sudo launchctl start com.exolabs.exo
```

### View Logs

```bash
# View real-time logs
tail -f /var/log/exo/exo.log
```

## Configuration

To customize your `exo` installation, you can create a configuration file.

1.  **Copy the example configuration:**
    ```bash
    sudo cp /opt/exo/scripts/exo_config_example.sh /opt/exo/scripts/exo_config.sh
    ```

2.  **Edit the configuration file:**
    ```bash
    sudo nano /opt/exo/scripts/exo_config.sh
    ```
    Uncomment and modify the settings you need.

3.  **Restart the service for changes to take effect:**
    ```bash
    sudo launchctl restart com.exolabs.exo
    ```

## Uninstalling the Service

To completely remove the `exo` service and all related files from your system, run the uninstaller script located in the installation directory.

```bash
sudo /opt/exo/scripts/uninstall_exo_service.sh
```

## ExoManager GUI

This repository also contains the project files for `ExoManager`, a native macOS GUI application for managing the `exo` service. You can build and run it from Xcode or using the included `build.sh` script.

```bash
# Build the app and install it to /Applications
./build.sh --install
```

## Contributing

Contributions are welcome! Please feel free to fork the repository, make changes, and submit a pull request.

1.  Fork this repository.
2.  Create a feature branch.
3.  Make your changes.
4.  Test thoroughly using `validate_project.sh`.
5.  Submit a pull request.

## License

This project is licensed under the GPL-3.0 License, the same as the `exo` framework itself.
