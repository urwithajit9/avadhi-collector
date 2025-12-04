#!/bin/bash
# Avadhi Linux Installation Script

# Define installation directories
INSTALL_DIR="/opt/avadhi"
SERVICE_FILE="avadhi.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_FILE}"

echo "--- Installing Avadhi Collector ---"

# 1. Create directory and copy files
sudo mkdir -p $INSTALL_DIR
sudo cp avadhi-collector $INSTALL_DIR/
sudo cp Config.toml $INSTALL_DIR/

# 2. Configure and copy service file
# NOTE: Replace 'avadhi-user' with the actual user/group
sed -i 's/avadhi-user/$(whoami)/g' $SERVICE_FILE
sed -i 's/avadhi-group/$(id -g -n)/g' $SERVICE_FILE

sudo cp $SERVICE_FILE $SERVICE_PATH

# 3. Reload, enable, and start service
sudo systemctl daemon-reload
sudo systemctl enable avadhi.service
sudo systemctl start avadhi.service

echo "--- Avadhi Service Started and Enabled on Boot ---"
sudo systemctl status avadhi.service --no-pager