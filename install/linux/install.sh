#!/bin/bash

# --- Avadhi Collector Installation Script ---

# Define the installation directory
INSTALL_DIR="/opt/avadhi-collector"

# IMPORTANT: Get the directory where THIS script is currently executing.
SCRIPT_SOURCE_DIR=$(dirname "$0")

# Get the original user who ran the script via sudo
CALLING_USER=${SUDO_USER:-$(whoami)}

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

# 2a. Copy the binary
BINARY_NAME="avadhi-collector"
if [ -f "$BINARY_NAME" ]; then
    sudo cp -f "$BINARY_NAME" "$INSTALL_DIR/"
else
    echo "FATAL ERROR: Collector binary ($BINARY_NAME) NOT found in the current directory. Check CI/CD packaging."
    exit 1
fi

# 2b. Copy the config example
CONFIG_EXAMPLE_NAME="Config.toml.example"
if [ -f "$CONFIG_EXAMPLE_NAME" ]; then
    sudo cp -f "$CONFIG_EXAMPLE_NAME" "$INSTALL_DIR/"
else
    echo "FATAL ERROR: Config example ($CONFIG_EXAMPLE_NAME) NOT found in the current directory. Check CI/CD packaging."
    exit 1
fi

# 2c. Create the active config file from the example
sudo cp -f "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"
echo "   Config.toml created successfully."

# --- Step 2d: CRITICAL OWNERSHIP FIX (Resolves Permission denied) ---
# Change ownership of the installation directory to the calling user,
# allowing them to write AvadhiConfig.toml later.
sudo chown -R "$CALLING_USER":"$CALLING_USER" "$INSTALL_DIR"
echo "   Directory ownership set to user $CALLING_USER."


# --- Step 3: Service Setup (Copy unit file) ---
echo "3. Installing systemd service template..."
SERVICE_UNIT_NAME="avadhi.service"
if [ -f "$SERVICE_UNIT_NAME" ]; then
    sudo cp -f "$SERVICE_UNIT_NAME" "/etc/systemd/system/avadhi@.service"
else
    echo "FATAL ERROR: Service unit ($SERVICE_UNIT_NAME) NOT found in the current directory."
    exit 1
fi


# --- Step 4: Enable Service Instance (DO NOT START) ---
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