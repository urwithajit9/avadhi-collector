#!/bin/bash

# --- Avadhi Collector Installation Script ---

# Define the installation directory
INSTALL_DIR="/opt/avadhi-collector"

# IMPORTANT: Get the directory where THIS script is currently executing.
# This ensures files are found regardless of where the script is called from.
SCRIPT_SOURCE_DIR=$(dirname "$0")

# --- Step 1: Directory Setup ---
echo "1. Setting up installation directory: $INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi
# Set directory ownership to root for security (as it's a system service location)
sudo chown -R root:root "$INSTALL_DIR"
echo "   Directory ownership set to root."

# --- Step 2: Copy Files ---
echo "2. Copying files to $INSTALL_DIR"
# 2a. Copy the binary and the example config
sudo cp "$SCRIPT_SOURCE_DIR/avadhi-collector" "$INSTALL_DIR/"
sudo cp "$SCRIPT_SOURCE_DIR/Config.toml.example" "$INSTALL_DIR/"

# 2b. CRITICAL FIX: Create the active config file from the example
# The collector binary needs Config.toml to exist with the public Supabase URLs.
sudo cp "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"

# --- Step 3: Service Setup ---
echo "3. Installing systemd service template..."
# Copy the service template to the systemd directory
sudo cp "$SCRIPT_SOURCE_DIR/avadhi.service" "/etc/systemd/system/avadhi@.service"

# --- Step 4: Enable and Start Service Instance ---
# Use the current calling user (who called sudo) as the service instance.
CALLING_USER=${SUDO_USER:-$(whoami)}
SERVICE_INSTANCE="avadhi@$CALLING_USER.service"

echo "4. Enabling and starting service instance: $SERVICE_INSTANCE"
sudo systemctl daemon-reload # Reload unit files to recognize the new template
sudo systemctl enable "$SERVICE_INSTANCE"
# Starting here will make it fail (due to missing tokens), but it registers the service.
sudo systemctl start "$SERVICE_INSTANCE"

# --- Step 5: Completion Message ---
echo "--------------------------------------------------------"
echo "✅ Installation Complete."
echo "--------------------------------------------------------"
echo "NEXT STEPS (MANDATORY): Run the interactive setup to provide tokens."
echo "--------------------------------------------------------"