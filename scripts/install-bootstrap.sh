#!/bin/bash

# --- Avadhi Collector Bootstrap Installer ---

# 1. Configuration: Update these variables for release management
REPO_OWNER="urwithajit9"
REPO_NAME="avadhi-collector"
ASSET_NAME="avadhi-linux.tar.gz"

# URL to download the latest release asset directly
DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/$ASSET_NAME"

# Temporary directory for download and extraction
TEMP_DIR=$(mktemp -d)

echo "--- Starting Avadhi Collector Quick Install ---"
echo "1. Downloading latest release from GitHub..."

# Download the file to the temporary directory
if curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"; then
    echo "   Download complete. Saved to $TEMP_DIR/$ASSET_NAME"
else
    echo "ERROR: Failed to download the collector archive from GitHub."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "2. Extracting archive..."
# Extract the archive. It creates the 'avadhi-linux' directory inside the temp folder.
if tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"; then
    echo "   Extraction successful."
else
    echo "ERROR: Failed to extract the archive."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# The extracted content is in $TEMP_DIR/avadhi-linux
INSTALL_DIR="$TEMP_DIR/avadhi-linux"

# 3. Running the Main Installation Script
echo "3. Executing main installation script (requires sudo for /opt permissions)..."

# Change directory and run the main install.sh script with sudo
# We need 'sudo' here because the main install.sh needs to move files to /opt and set up the systemd service.
# We also use bash to execute the script in case the user's default shell is not bash compatible.
if sudo bash "$INSTALL_DIR/install.sh"; then
    echo "✅ Collector installation finished successfully."
    echo "Please follow the remaining manual authentication steps outlined in the output above."
else
    echo "FATAL: Main installation script failed."
    # The install.sh script should already print detailed errors.
fi

# 4. Cleanup
echo "4. Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Cleanup finished. Installation status can be checked with 'sudo systemctl status avadhi@$(whoami).service'."