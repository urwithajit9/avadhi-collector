#!/bin/bash

# --- Avadhi Collector Quick Installer (Automated Setup) ---

# 1. Configuration:
REPO_OWNER="urwithajit9"
REPO_NAME="avadhi-collector"
ASSET_NAME="avadhi-linux.tar.gz"
DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/$ASSET_NAME"
TEMP_DIR=$(mktemp -d)
CURRENT_USER=$(whoami)
SERVICE_INSTANCE="avadhi@$CURRENT_USER.service"

echo "--- Starting Avadhi Collector Quick Install ---"

# --- 1. Download and Extract ---
echo "1. Downloading latest release from GitHub..."

if ! curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"; then
    echo "ERROR: Failed to download archive. Check repository access."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "2. Extracting archive..."
if ! tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"; then
    echo "ERROR: Failed to extract the archive."
    rm -rf "$TEMP_DIR"
    exit 1
fi

INSTALL_DIR="$TEMP_DIR/avadhi-linux"
BINARY_PATH="$INSTALL_DIR/avadhi-collector"

# --- 2. Run the Main Installation Script ---
echo "3. Executing main installation script (requires sudo for /opt permissions)..."

# Run the installer which moves files, sets ownership, and registers the systemd service.
if ! sudo bash "$INSTALL_DIR/install.sh"; then
    echo "FATAL: Main installation script failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# The files are now in /opt/avadhi-collector
FINAL_BINARY="/opt/avadhi-collector/avadhi-collector"
WEB_APP_URL="https://www.avadhi.space/auth"

# --- 3. Mandatory User Authentication (Interactive Setup) ---
echo "--------------------------------------------------------"
echo "--- MANDATORY: Initial User Setup ---"
echo "The service requires your private tokens to run."
echo "Please visit the URL below to retrieve your User ID and Tokens:"
echo "$WEB_APP_URL"
echo ""

# Stop the service instance that automatically started (it would fail without tokens)
echo "4. Temporarily stopping $SERVICE_INSTANCE for setup..."
sudo systemctl stop "$SERVICE_INSTANCE"

# Run the binary in setup mode (as the user, not sudo)
echo "5. Starting interactive setup. Please enter your tokens below."

# We need to run the final binary directly from /opt for the AvadhiConfig.toml to be created correctly
if ! "$FINAL_BINARY" --setup; then
    echo "ERROR: Interactive token setup failed or was interrupted."
    # We still clean up, but the service won't work until this step is manually repeated.
else
    # --- 4. Final Service Activation ---
    echo ""
    echo "6. Tokens saved! Restarting $SERVICE_INSTANCE for persistent tracking."
    sudo systemctl restart "$SERVICE_INSTANCE"
    echo "--------------------------------------------------------"
    echo "✅ INSTALLATION COMPLETE."
    echo "The Avadhi Collector is now running in the background."
    echo "--------------------------------------------------------"
fi

# --- 5. Cleanup ---
echo "7. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"