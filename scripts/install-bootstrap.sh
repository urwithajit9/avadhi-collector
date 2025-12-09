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
INSTALL_DIR="/opt/avadhi-collector"

echo "--- Starting Avadhi Collector Quick Install ---"

# --- 0. Pre-Installation Cleanup (Guaranteed Stop/Disable) ---
# Ensures the environment is clean before starting the install.
echo "0. Running pre-installation cleanup..."
# Stop the service instance if it exists
sudo systemctl stop "$SERVICE_INSTANCE" 2>/dev/null || true
# Disable the service instance
sudo systemctl disable "$SERVICE_INSTANCE" 2>/dev/null || true
# Reload systemd configuration
sudo systemctl daemon-reload 2>/dev/null || true
# Remove the entire installation directory
sudo rm -rf "$INSTALL_DIR" 2>/dev/null || true


# --- 1. Download and Extract ---
echo "1. Downloading latest release from GitHub..."
if ! curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"; then
    echo "ERROR: Failed to download archive. Check repository access or URL."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "2. Extracting archive..."
if ! tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"; then
    echo "ERROR: Failed to extract the archive. Corrupt file or missing binary?"
    rm -rf "$TEMP_DIR"
    exit 1
fi

EXTRACTED_DIR="$TEMP_DIR/avadhi-linux"
FINAL_BINARY="$INSTALL_DIR/avadhi-collector"
WEB_APP_URL="https://www.avadhi.space/auth"

# --- 2. Run the Main Installation Script (CRITICAL FIX: Execution Context) ---
# Fix: Change directory to the extracted folder before executing install.sh.
# This ensures that install.sh's commands (cp avadhi-collector) find the files locally (./).
echo "3. Executing main installation script (requires sudo for /opt permissions)..."

if ! (cd "$EXTRACTED_DIR" && sudo bash install.sh); then
    echo "FATAL: Main installation script failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# --- 3. Mandatory User Authentication (Interactive Setup) ---
echo "--------------------------------------------------------"
echo "--- MANDATORY: Initial User Setup ---"
echo "The service requires your private tokens to run."
echo "Please visit the URL below to retrieve your User ID and Tokens:"
echo "$WEB_APP_URL"
echo "--------------------------------------------------------"

# Run setup binary (as the user, not sudo)
echo "4. Starting interactive setup. Please enter your tokens below."

# Fix: Use 'cd $INSTALL_DIR' inside runuser command. This sets the working directory
# to /opt/avadhi-collector, allowing the binary to find Config.toml in the same location.
SETUP_COMMAND="cd $INSTALL_DIR && $FINAL_BINARY --setup"

if ! sudo runuser -l "$CURRENT_USER" -c "$SETUP_COMMAND"; then
    echo "ERROR: Interactive token setup failed or was interrupted. Please check logs for configuration errors."
    # The installation is technically complete, but the setup failed. Proceed to cleanup.
else
    # --- 4. Final Service Activation ---
    echo ""
    echo "5. Tokens saved! Restarting $SERVICE_INSTANCE for persistent tracking."
    sudo systemctl restart "$SERVICE_INSTANCE"
    echo "--------------------------------------------------------"
    echo "✅ INSTALLATION COMPLETE."
    echo "The Avadhi Collector is now running in the background."
    echo "--------------------------------------------------------"
fi

# --- 5. Cleanup ---
echo "6. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "Cleanup finished. Check status with: sudo systemctl status $SERVICE_INSTANCE"