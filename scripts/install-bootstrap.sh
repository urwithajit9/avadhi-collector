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

# --- 2. Run the Main Installation Script (CRITICAL FIX: Execution Context) ---
# Fix: Change directory to the extracted folder before executing install.sh.
echo "3. Executing main installation script (requires sudo for /opt permissions)..."

if ! (cd "$EXTRACTED_DIR" && sudo bash install.sh); then
    echo "FATAL: Main installation script failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# --- 3. Capture Optional Resume Date (New Interactive Step) ---
# The prompt is interactive and will wait for input in the TTY shell where 'curl | bash' is running.
RESUME_DATE_ARG=""
echo "--------------------------------------------------------"
echo "--- OPTIONAL: Resume Tracking Date ---"
read -rp "If you are reinstalling, enter the last date successfully POSTED (YYYY-MM-DD), or press ENTER to track full history: " RESUME_DATE

# Validate and format the date argument for the binary
if [[ "$RESUME_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    # CRITICAL ASSUMPTION: The avadhi-collector binary will be updated to accept this flag.
    RESUME_DATE_ARG=" --last-posted-date \"$RESUME_DATE\""
    echo "Using resume date: $RESUME_DATE"
else
    echo "No resume date provided. Collector will track all historical sessions."
fi

# --- 4. Final Completion Message (Decoupled Setup Instructions) ---

# Construct the full setup command including the optional resume date
SETUP_COMMAND="cd $INSTALL_DIR && $FINAL_BINARY --setup$RESUME_DATE_ARG"

echo "--------------------------------------------------------"
echo "✅ CORE INSTALLATION COMPLETE."
echo "--------------------------------------------------------"
echo ""
echo "🔥 NEXT MANDATORY STEP: INTERACTIVE SETUP 🔥"
echo ""
echo "The Collector requires your user-specific tokens. Please perform the following steps:"
echo ""
echo "Step A: Get Tokens:"
echo "   1. Visit the following URL to log in and get your credentials:"
echo "      $WEB_APP_URL"
echo ""
echo "Step B: Run Setup Command:"
echo "   2. Run the command below to launch the interactive prompt and save your tokens."
echo "      This command now includes the resume date (if provided above)."
echo ""
echo "      $SETUP_COMMAND"
echo ""
echo "Step C: Start Service:"
echo "   3. After setup is complete, run the command below to start the collector service:"
echo ""
echo "      sudo systemctl restart $SERVICE_INSTANCE"
echo ""
echo "--------------------------------------------------------"


# --- 5. Cleanup ---
echo "5. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "Cleanup finished. Installation directory is $INSTALL_DIR"