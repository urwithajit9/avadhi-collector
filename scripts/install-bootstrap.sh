#!/bin/bash

# --- Avadhi Collector Quick Installer (Automated Setup) ---

set -e

# --- 1. Configuration ---
REPO_OWNER="urwithajit9"
REPO_NAME="avadhi-collector"
ASSET_NAME="avadhi-linux.tar.gz"
DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/$ASSET_NAME"

TEMP_DIR=$(mktemp -d)
INSTALL_DIR="/opt/avadhi-collector"
SERVICE_USER="avadhi"

TEMPLATE_UNIT="avadhi@.service"
TIMER_UNIT="avadhi.timer"

WEB_APP_URL="https://www.avadhi.space/auth"

echo "--- Starting Avadhi Collector Quick Install (Timer-based) ---"

# --- 0. Pre-Installation Cleanup ---
echo "0. Running pre-installation cleanup..."
sudo systemctl stop "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl disable "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl stop "$TEMPLATE_UNIT" 2>/dev/null || true

sudo systemctl daemon-reload 2>/dev/null || true
sudo rm -rf "$INSTALL_DIR" 2>/dev/null || true

# --- 1. Download and Extract ---
echo "1. Downloading latest release from GitHub..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"; then
    echo "ERROR: Failed to download archive."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "2. Extracting archive..."
if ! tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"; then
    echo "ERROR: Failed to extract archive."
    rm -rf "$TEMP_DIR"
    exit 1
fi

EXTRACTED_DIR="$TEMP_DIR/avadhi-linux"

# --- 2. Run Main Installation Script ---
echo "3. Executing main installation script (requires sudo)..."
if ! (cd "$EXTRACTED_DIR" && sudo bash install.sh); then
    echo "FATAL: Main installation script failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# --- 3. Post-Install Authentication Guidance ---
echo "--------------------------------------------------------"
echo "✅ CORE INSTALLATION COMPLETE"
echo "--------------------------------------------------------"
echo ""

echo "ℹ️ AUTHENTICATION (OUT OF BAND)"
echo ""
if [ -f "$INSTALL_DIR/AvadhiConfig.toml" ]; then
    echo "User configuration detected at:"
    echo "  $INSTALL_DIR/AvadhiConfig.toml"
    echo "The collector is ready to run with existing credentials."
else
    echo "No user configuration detected."
    echo "To authenticate the collector and enable posting, run the interactive setup:"
    echo ""
    echo "  sudo -u $SERVICE_USER $INSTALL_DIR/avadhi-collector setup"
    echo ""
    echo "Follow the prompts to login via browser, then enter:"
    echo "  - User ID (UUID)"
    echo "  - Access Token (JWT)"
    echo "  - Refresh Token"
    echo ""
    echo "After setup, $INSTALL_DIR/AvadhiConfig.toml will be created with secure permissions."
    echo "Tokens can also be obtained from the web app at:"
    echo "  $WEB_APP_URL"
fi
echo ""

# --- 4. Verification Instructions ---
echo "--------------------------------------------------------"
echo "🔍 VERIFY INSTALLATION"
echo "--------------------------------------------------------"
echo ""
echo "1. Verify Timer is enabled:"
echo ""
echo "   systemctl list-timers | grep avadhi"
echo ""
echo "   Expected output includes:"
echo "     NEXT run time, LAST run time, avadhi.timer → avadhi@default.service"
echo ""
echo "2. Verify service definition (should be inactive between runs):"
echo ""
echo "   systemctl status $TEMPLATE_UNIT"
echo ""
echo "   Expected:"
echo "     Active: inactive (dead)"
echo ""
echo "3. View logs from last run (if any):"
echo ""
echo "   journalctl -u $TEMPLATE_UNIT --since today"
echo ""
echo "--------------------------------------------------------"

# --- 5. Cleanup ---
echo "5. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "Cleanup finished. Installation directory: $INSTALL_DIR"
echo ""
echo "✅ Bootstrap installation finished. Timer-based execution ready."
echo "To run setup manually later: sudo -u $SERVICE_USER $INSTALL_DIR/avadhi-collector setup"
echo "--------------------------------------------------------"
