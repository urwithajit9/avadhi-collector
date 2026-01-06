#!/bin/bash
set -e

INSTALL_DIR="/opt/avadhi-collector"
SERVICE_USER="avadhi"
TEMPLATE_UNIT="avadhi@.service"
TIMER_UNIT="avadhi.timer"

echo "Stopping Avadhi Collector timer and service..."
sudo systemctl stop "$TIMER_UNIT" 2>/dev/null || true
sudo systemctl stop "${TEMPLATE_UNIT%.*}@default.service" 2>/dev/null || true

echo "Disabling timer..."
sudo systemctl disable "$TIMER_UNIT" 2>/dev/null || true

echo "Removing systemd unit files..."
sudo rm -f "/etc/systemd/system/$TIMER_UNIT"
sudo rm -f "/etc/systemd/system/$TEMPLATE_UNIT"
sudo systemctl daemon-reload

echo "Removing installation directory..."
sudo rm -rf "$INSTALL_DIR"

echo "Optionally removing system user '$SERVICE_USER'..."
sudo userdel "$SERVICE_USER" 2>/dev/null || true

echo "Cleaning journal logs..."
sudo journalctl --vacuum-files=1 --unit=avadhi@default.service 2>/dev/null || true
sudo journalctl --vacuum-files=1 --unit=avadhi.timer 2>/dev/null || true

echo "✅ Avadhi Collector has been fully uninstalled."
