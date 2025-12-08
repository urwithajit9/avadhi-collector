#!/bin/bash

# --- Configuration ---
INSTALL_DIR="/opt/avadhi-collector"
SERVICE_TEMPLATE="avadhi.service"
BINARY_NAME="avadhi-collector"
CONFIG_EXAMPLE="Config.toml.example"
CURRENT_USER=$(whoami)

echo "--- Avadhi Collector Installation Script ---"

# --- 1. Setup Installation Directory and Ownership ---
echo "1. Setting up installation directory: $INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi
# Set ownership to the user running the script
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$INSTALL_DIR"
echo "   Directory ownership set to $CURRENT_USER."


# --- 2. Copy Files (Assuming they are in the current working directory) ---
echo "2. Copying files to $INSTALL_DIR"
cp $BINARY_NAME "$INSTALL_DIR/"
# Copy the example file as the active admin config
cp $CONFIG_EXAMPLE "$INSTALL_DIR/Config.toml"

# --- 3. Install Systemd Service Template ---
echo "3. Installing systemd service template..."

# Define the location for the systemd service file
SYSTEM_SERVICE_PATH="/etc/systemd/system/avadhi@.service"

# Copy the service template
sudo cp $SERVICE_TEMPLATE "$SYSTEM_SERVICE_PATH"

# Reload systemd manager configuration
sudo systemctl daemon-reload

# --- 4. Enable and Start Service Instance ---
# The service instance name includes the username, e.g., avadhi@john.service
SERVICE_INSTANCE="avadhi@$CURRENT_USER.service"

echo "4. Enabling and starting service instance: $SERVICE_INSTANCE"
sudo systemctl enable "$SERVICE_INSTANCE"
# Start the service
sudo systemctl start "$SERVICE_INSTANCE"

echo "--------------------------------------------------------"
echo "✅ Installation Complete."
echo "--------------------------------------------------------"
echo "NEXT STEPS (MANDATORY):"
echo "1. Configure Admin: Edit $INSTALL_DIR/Config.toml to set your Supabase URLs."
echo "2. Initial Setup: The service will FAIL until tokens are provided."
echo "   You MUST run the binary manually (as user $CURRENT_USER) ONCE to authenticate:"
echo "   cd $INSTALL_DIR"
echo "   ./$BINARY_NAME"
echo "   Follow the prompts to enter your User ID and Tokens."
echo "3. Restart Service: After successful setup, restart the service to run persistently:"
echo "   sudo systemctl restart $SERVICE_INSTANCE"
echo "4. Check Status: sudo systemctl status $SERVICE_INSTANCE"
echo "5. View Logs: sudo journalctl -u $SERVICE_INSTANCE -f -n 50"
echo "--------------------------------------------------------"