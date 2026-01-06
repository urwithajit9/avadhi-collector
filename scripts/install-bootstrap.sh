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

SERVICE_UNIT="avadhi-collector.service"
TIMER_UNIT="avadhi-collector.timer"

WEB_APP_URL="https://www.avadhi.space/auth"

echo "--- Starting Avadhi Collector Quick Install (Timer-based) ---"

# --- 0. Pre-Installation Cleanup ---
echo "0. Running pre-installation cleanup..."

sudo systemctl stop "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl disable "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl stop "$SERVICE_UNIT" 2>/dev/null || true

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

# --- 3. Post-Install Information ---
echo "--------------------------------------------------------"
echo "✅ CORE INSTALLATION COMPLETE"
echo "--------------------------------------------------------"
echo ""
echo "ℹ️ AUTHENTICATION (OUT OF BAND)"
echo ""
echo "This installation does NOT perform interactive setup."
echo "Ensure AvadhiConfig.toml exists at:"
echo ""
echo "  $INSTALL_DIR/AvadhiConfig.toml"
echo ""
echo "Tokens can be obtained from:"
echo "  $WEB_APP_URL"
echo ""

# --- 4. Verification Instructions ---
echo "--------------------------------------------------------"
echo "🔍 VERIFY INSTALLATION"
echo "--------------------------------------------------------"
echo ""
echo "1. Verify Timer (PRIMARY CHECK):"
echo ""
echo "   systemctl list-timers | grep avadhi"
echo ""
echo "   Expected:"
echo "     avadhi-collector.timer with NEXT and LAST timestamps"
echo ""
echo "2. Verify Service Definition (should be inactive between runs):"
echo ""
echo "   systemctl status $SERVICE_UNIT"
echo ""
echo "   Expected:"
echo "     Active: inactive (dead)"
echo ""
echo "3. View Logs from Last Run:"
echo ""
echo "   journalctl -u $SERVICE_UNIT --since today"
echo ""
echo "--------------------------------------------------------"

# --- 5. Cleanup ---
echo "5. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Cleanup finished. Installation directory: $INSTALL_DIR"
