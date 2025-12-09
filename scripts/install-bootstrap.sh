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
FINAL_BINARY="$INSTALL_DIR/avadhi-collector"
WEB_APP_URL="https://www.avadhi.space/auth"

echo "--- Starting Avadhi Collector Quick Install ---"

# --- 0. Pre-Installation Cleanup ---
echo "0. Running pre-installation cleanup..."
sudo systemctl stop "$SERVICE_INSTANCE" 2>/dev/null || true
sudo systemctl disable "$SERVICE_INSTANCE" 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true
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

# --- 2. Run the Main Installation Script (File Copying & Permissions) ---
echo "3. Executing main installation script (requires sudo for /opt permissions)..."

# CRITICAL FIX: Change directory to the extracted folder before executing install.sh.
if ! (cd "$EXTRACTED_DIR" && sudo bash install.sh); then
    echo "FATAL: Main installation script failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# --- 3. Final Completion Message (Decoupled Setup Instructions) ---

echo "--------------------------------------------------------"
echo "✅ CORE INSTALLATION COMPLETE."
echo "--------------------------------------------------------"
echo ""
echo "🔥 NEXT MANDATORY STEP: INTERACTIVE SETUP 🔥"
echo ""
echo "The Collector requires your user-specific tokens."
echo "Please perform the following steps:"
echo ""
echo "Step A: Get Tokens:"
echo "   1. Visit the following URL to log in and get your credentials:"
echo "      $WEB_APP_URL"
echo ""
echo "Step B: Run Setup Command:"
echo "   2. Run the command below to launch the interactive prompt and save your tokens:"
echo ""
echo "      cd $INSTALL_DIR && $FINAL_BINARY --setup"
echo ""
echo "   This ensures the binary is running from the correct directory to find Config.toml."
echo ""
echo "Step C: Start Service:"
echo "   3. After setup is complete, run the command below to start the collector service:"
echo ""
echo "      sudo systemctl restart $SERVICE_INSTANCE"
echo ""
echo "--------------------------------------------------------"


# --- 4. Cleanup ---
echo "4. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "Cleanup finished. Installation directory is $INSTALL_DIR"