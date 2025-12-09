#!/bin/bash

# --- Avadhi Collector Installation Script ---

# Define the installation directory
INSTALL_DIR="/opt/avadhi-collector"

# IMPORTANT: Get the directory where THIS script is currently executing.
SCRIPT_SOURCE_DIR=$(dirname "$0")

# --- Step 1: Directory Setup ---
echo "1. Setting up installation directory: $INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi
# Set directory ownership to root AFTER copying is done.

# --- Step 2: Copy Files ---
echo "2. Copying files to $INSTALL_DIR"
# Use -f (force) to ensure successful copy over any leftover busy files
sudo cp -f "$SCRIPT_SOURCE_DIR/avadhi-collector" "$INSTALL_DIR/"
sudo cp -f "$SCRIPT_SOURCE_DIR/Config.toml.example" "$INSTALL_DIR/"

# CRITICAL: Create the active config file from the example
sudo cp -f "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"

# Set directory ownership to root AFTER copying is done
sudo chown -R root:root "$INSTALL_DIR"
echo "   Directory ownership set to root."


# --- Step 3: Service Setup (FIX: Copy unit file to /etc/systemd/system) ---
echo "3. Installing systemd service template..."
# Copy the service template to the systemd directory
sudo cp -f "$SCRIPT_SOURCE_DIR/avadhi.service" "/etc/systemd/system/avadhi@.service"

# --- Step 4: Enable Service Instance (DO NOT START) ---
CALLING_USER=${SUDO_USER:-$(whoami)}
SERVICE_INSTANCE="avadhi@$CALLING_USER.service"

echo "4. Enabling service instance: $SERVICE_INSTANCE"
sudo systemctl daemon-reload # Reload unit files to recognize the new template
sudo systemctl enable "$SERVICE_INSTANCE"

# --- Step 5: Completion Message ---
echo "--------------------------------------------------------"
echo "✅ Installation Complete."
echo "--------------------------------------------------------"
echo "NEXT STEPS (MANDATORY): Run the interactive setup to provide tokens."
echo "--------------------------------------------------------"