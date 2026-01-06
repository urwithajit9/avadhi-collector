#!/bin/bash

# --- Avadhi Collector Installation Script ---

# Define the installation directory
INSTALL_DIR="/opt/avadhi-collector"

# Dedicated system user for the collector
SERVICE_USER="avadhi"

# IMPORTANT: Get the directory where THIS script is currently executing.
SCRIPT_SOURCE_DIR=$(dirname "$0")

echo "--- INSTALL SCRIPT PATHS CHECK ---"
echo "Installation Directory: $INSTALL_DIR"
echo "Service User: $SERVICE_USER"
echo "Checking for local assets: avadhi-collector, Config.toml.example, avadhi-collector.service, avadhi-collector.timer"
echo "----------------------------------"

# --- Step 0: Ensure system user exists ---
echo "0. Ensuring system user '$SERVICE_USER' exists..."
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    sudo useradd \
        --system \
        --home "$INSTALL_DIR" \
        --shell /usr/sbin/nologin \
        "$SERVICE_USER"
    echo "   System user '$SERVICE_USER' created."
else
    echo "   System user '$SERVICE_USER' already exists."
fi

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

# 2c. Create the active config file from the example (do not overwrite if exists)
if [ ! -f "$INSTALL_DIR/Config.toml" ]; then
    sudo cp "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"
    echo "   Config.toml created successfully."
else
    echo "   Config.toml already exists. Skipping."
fi

# --- Step 2d: Ownership ---
echo "   Setting ownership to $SERVICE_USER"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"

# --- Step 3: Install systemd units ---
echo "3. Installing systemd units..."

SERVICE_UNIT_NAME="avadhi-collector.service"
TIMER_UNIT_NAME="avadhi-collector.timer"

if [ -f "$SERVICE_UNIT_NAME" ]; then
    sudo cp -f "$SERVICE_UNIT_NAME" "/etc/systemd/system/$SERVICE_UNIT_NAME"
else
    echo "FATAL ERROR: Service unit ($SERVICE_UNIT_NAME) NOT found."
    exit 1
fi

if [ -f "$TIMER_UNIT_NAME" ]; then
    sudo cp -f "$TIMER_UNIT_NAME" "/etc/systemd/system/$TIMER_UNIT_NAME"
else
    echo "FATAL ERROR: Timer unit ($TIMER_UNIT_NAME) NOT found."
    exit 1
fi

# --- Step 4: Enable timer ONLY ---
echo "4. Enabling daily timer (service will be triggered by timer)..."
sudo systemctl daemon-reload
sudo systemctl enable "$TIMER_UNIT_NAME"

# --- Step 5: Completion Message ---
echo "--------------------------------------------------------"
echo "✅ Installation Complete (Timer-based mode)"
echo "--------------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Ensure AvadhiConfig.toml exists in $INSTALL_DIR"
echo "2. Tokens must be provisioned non-interactively (Option 1)"
echo "3. Verify timer:"
echo "     systemctl list-timers | grep avadhi"
echo "--------------------------------------------------------"
