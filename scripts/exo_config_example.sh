#!/bin/bash

# Example configuration file for exo startup script
# Copy this file to /opt/exo/scripts/exo_config.sh and modify as needed
# Then update start_exo.sh to source this configuration

# =============================================================================
# BASIC CONFIGURATION
# =============================================================================

# Model storage location
export EXO_HOME="/opt/exo/.cache/exo"

# Hugging Face endpoint (useful for restricted regions)
export HF_ENDPOINT="https://huggingface.co"

# Debug logging level (0-9, higher = more verbose)
export DEBUG=0

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

# Discovery module (udp, manual, tailscale)
export EXO_DISCOVERY_MODULE="udp"

# Tailscale API key (if using tailscale discovery)
# export EXO_TAILSCALE_API_KEY="your_tailscale_api_key_here"

# Manual peer configuration (if using manual discovery)
# export EXO_MANUAL_PEERS="192.168.1.100:52415,192.168.1.101:52415"

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# GPU memory fraction (0.0 to 1.0)
export EXO_GPU_MEMORY_FRACTION="0.9"

# Default model to load on startup
# export EXO_DEFAULT_MODEL="llama-3.2-3b"

# =============================================================================
# WEB INTERFACE CONFIGURATION
# =============================================================================

# Web interface port
export EXO_WEB_PORT="52415"

# Web interface host
export EXO_WEB_HOST="0.0.0.0"

# =============================================================================
# ADVANCED CONFIGURATION
# =============================================================================

# Custom exo command line arguments
# export EXO_EXTRA_ARGS="--discovery-module tailscale"

# Tinygrad debug level (if using tinygrad engine)
# export TINYGRAD_DEBUG=0

# =============================================================================
# USAGE INSTRUCTIONS
# =============================================================================

# To use this configuration:
# 1. Copy this file: cp exo_config_example.sh /opt/exo/scripts/exo_config.sh
# 2. Edit the configuration: nano /opt/exo/scripts/exo_config.sh
# 3. Uncomment and modify the settings you need
# 4. Restart the service: sudo launchctl restart com.exolabs.exo 