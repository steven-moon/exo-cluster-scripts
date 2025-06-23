#!/bin/bash

# Basic configuration file for exo startup script
# Copy this file to /opt/exo/scripts/exo_config.sh and modify as needed

# =============================================================================
# ESSENTIAL CONFIGURATION
# =============================================================================

# Model storage location (uncomment to change)
# export EXO_HOME="/opt/exo/.cache/exo"

# Cache directories (automatically set based on EXO_HOME)
# export HF_HOME="/opt/exo/.cache/exo"
# export TRANSFORMERS_CACHE="/opt/exo/.cache/exo/transformers"
# export HF_DATASETS_CACHE="/opt/exo/.cache/exo/datasets"

# Web interface configuration
# export EXO_WEB_PORT="52415"
# export EXO_WEB_HOST="0.0.0.0"

# =============================================================================
# NETWORK DISCOVERY
# =============================================================================

# Discovery method: udp (automatic), manual (specify peers), or tailscale
# export EXO_DISCOVERY_MODULE="udp"

# For manual discovery, specify peer addresses
# export EXO_MANUAL_PEERS="192.168.1.100:52415,192.168.1.101:52415"

# For Tailscale discovery
# export EXO_TAILSCALE_API_KEY="your_tailscale_api_key"

# =============================================================================
# ADVANCED SETTINGS (uncomment if needed)
# =============================================================================

# Debug logging (0-9, higher = more verbose)
# export DEBUG=0

# GPU memory usage (0.0 to 1.0)
# export EXO_GPU_MEMORY_FRACTION="0.9"

# Default model to load
# export EXO_DEFAULT_MODEL="llama-3.2-3b"

# =============================================================================
# SETUP INSTRUCTIONS
# =============================================================================

# To use this configuration:
# 1. Copy this file: cp scripts/exo_config_example.sh /opt/exo/scripts/exo_config.sh
# 2. Uncomment and modify the settings you need
# 3. Restart the service: sudo launchctl restart com.exolabs.exo 