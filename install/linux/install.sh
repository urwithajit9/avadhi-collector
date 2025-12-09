#!/bin/bash

# --- Avadhi Collector Installation Script ---
# ASSUMPTION: This script is executed from the temporary directory
# where all assets (avadhi-collector, Config.toml.example, avadhi.service) reside.

# Define the installation directory
INSTALL_DIR="/opt/avadhi-collector"

echo "--- INSTALL SCRIPT PATHS CHECK ---"
echo "Installation Directory: $INSTALL_DIR"
echo "Checking for local assets: avadhi-collector, Config.toml.example, avadhi.service"
echo "----------------------------------"

# --- Step 1: Directory Setup ---
echo "1. Setting up installation directory: $INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi

# --- Step 2: Copy Files ---
echo "2. Copying files to $INSTALL_DIR"

# 2a. CRITICAL: Copy the binary
BINARY_NAME="avadhi-collector"
if [ -f "$BINARY_NAME" ]; then
    # Binary is found in the current directory
    sudo cp -f "$BINARY_NAME" "$INSTALL_DIR/"
else
    echo "FATAL ERROR: Collector binary ($BINARY_NAME) NOT found in the current directory. Check CI/CD packaging."
    exit 1
fi

# 2b. Copy the config example
CONFIG_EXAMPLE_NAME="Config.toml.example"
if [ -f "$CONFIG_EXAMPLE_NAME" ]; then
    # Config example is found in the current directory
    sudo cp -f "$CONFIG_EXAMPLE_NAME" "$INSTALL_DIR/"
else
    echo "FATAL ERROR: Config example ($CONFIG_EXAMPLE_NAME) NOT found in the current directory. Check CI/CD packaging."
    exit 1
fi

# 2c. Create the active config file from the example
sudo cp -f "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"
echo "   Config.toml created successfully."

# Set directory ownership to root AFTER copying is done
sudo chown -R root:root "$INSTALL_DIR"
echo "   Directory ownership set to root."


# --- Step 3: Service Setup (Copy unit file) ---
echo "3. Installing systemd service template..."
SERVICE_UNIT_NAME="avadhi.service"
if [ -f "$SERVICE_UNIT_NAME" ]; then
    # Service unit is found in the current directory
    sudo cp -f "$SERVICE_UNIT_NAME" "/etc/systemd/system/avadhi@.service"
else
    echo "FATAL ERROR: Service unit ($SERVICE_UNIT_NAME) NOT found in the current directory."
    exit 1
fi


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