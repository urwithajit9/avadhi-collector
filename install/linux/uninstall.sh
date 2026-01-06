#!/bin/bash

# --- Avadhi Collector Uninstall Script ---

set -e

INSTALL_DIR="/opt/avadhi-collector"
SERVICE_USER="avadhi"

DISPATCHER_UNIT="avadhi.service"
TEMPLATE_UNIT="avadhi@.service"
TIMER_UNIT="avadhi.timer"

echo "--------------------------------------------------"
echo "--- Avadhi Collector Uninstall Script ---"
echo "--------------------------------------------------"

# --- Step 1: Stop and disable timer ---
echo "1. Stopping and disabling timer..."
sudo systemctl stop "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl disable "$TIMER_UNIT" 2>/dev/null || true

# --- Step 2: Stop any running services ---
echo "2. Stopping running services..."
sudo systemctl stop "$DISPATCHER_UNIT" 2>/dev/null || true
sudo systemctl stop "$TEMPLATE_UNIT" 2>/dev/null || true

# --- Step 3: Remove systemd unit files ---
echo "3. Removing systemd unit files..."
sudo rm -f "/etc/systemd/system/$DISPATCHER_UNIT"
sudo rm -f "/etc/systemd/system/$TEMPLATE_UNIT"
sudo rm -f "/etc/systemd/system/$TIMER_UNIT"

sudo systemctl daemon-reload

# --- Step 4: Remove installation directory ---
echo "4. Removing installation directory..."
sudo rm -rf "$INSTALL_DIR"

# --- Step 5: Remove system user ---
echo "5. Removing system user '$SERVICE_USER'..."
if id "$SERVICE_USER" >/dev/null 2>&1; then
    sudo userdel "$SERVICE_USER"
    echo "   User '$SERVICE_USER' removed."
else
    echo "   User '$SERVICE_USER' does not exist. Skipping."
fi

# --- Completion ---
echo "--------------------------------------------------"
echo "✅ Avadhi Collector fully uninstalled."
echo "--------------------------------------------------"
