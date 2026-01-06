#!/bin/bash

# --- Avadhi Collector Installation Script ---
# Mode: systemd timer + dispatcher + dedicated system user

set -e

# --- Configuration ---
INSTALL_DIR="/opt/avadhi-collector"
SERVICE_USER="avadhi"

# Directory where this script is executed from
SCRIPT_SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "--------------------------------------------------"
echo "--- Avadhi Collector Installation Script ---"
echo "Installation Directory : $INSTALL_DIR"
echo "Service User           : $SERVICE_USER"
echo "Expected assets:"
echo "  - avadhi-collector"
echo "  - Config.toml.example"
echo "  - avadhi.service      (dispatcher)"
echo "  - avadhi@.service     (worker template)"
echo "  - avadhi.timer"
echo "--------------------------------------------------"

# --- Step 0: Ensure dedicated system user exists ---
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

# --- Step 1: Create installation directory ---
echo "1. Setting up installation directory: $INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi

# --- Step 2: Copy application files ---
echo "2. Copying application files..."

# Binary
if [ -f "$SCRIPT_SOURCE_DIR/avadhi-collector" ]; then
    sudo cp -f "$SCRIPT_SOURCE_DIR/avadhi-collector" "$INSTALL_DIR/"
else
    echo "FATAL: avadhi-collector binary not found."
    exit 1
fi

# Config template
if [ -f "$SCRIPT_SOURCE_DIR/Config.toml.example" ]; then
    sudo cp -f "$SCRIPT_SOURCE_DIR/Config.toml.example" "$INSTALL_DIR/"
else
    echo "FATAL: Config.toml.example not found."
    exit 1
fi

# Create active config if missing
if [ ! -f "$INSTALL_DIR/Config.toml" ]; then
    sudo cp "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml"
    echo "   Config.toml created."
else
    echo "   Config.toml already exists. Skipping."
fi

# --- Step 3: Ownership ---
echo "3. Setting ownership to $SERVICE_USER"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"

# --- Step 4: Install systemd units ---
echo "4. Installing systemd units..."

DISPATCHER_UNIT="avadhi.service"
TEMPLATE_UNIT="avadhi@.service"
TIMER_UNIT="avadhi.timer"

for UNIT in "$DISPATCHER_UNIT" "$TEMPLATE_UNIT" "$TIMER_UNIT"; do
    if [ -f "$SCRIPT_SOURCE_DIR/$UNIT" ]; then
        sudo cp -f "$SCRIPT_SOURCE_DIR/$UNIT" "/etc/systemd/system/$UNIT"
        echo "   Installed $UNIT"
    else
        echo "FATAL: Required unit file '$UNIT' not found."
        exit 1
    fi
done

# --- Step 5: Enable timer only ---
echo "5. Enabling daily timer (service is timer-triggered)..."
sudo systemctl daemon-reload
sudo systemctl enable avadhi.timer

# --- Completion ---
echo "--------------------------------------------------"
echo "✅ Installation Complete (Timer-based execution)"
echo "--------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Ensure tokens are provisioned in:"
echo "     $INSTALL_DIR/Config.toml"
echo "2. Verify timer:"
echo "     systemctl list-timers | grep avadhi"
echo "3. Inspect logs after first run:"
echo "     journalctl -u avadhi.service"
echo "--------------------------------------------------"
