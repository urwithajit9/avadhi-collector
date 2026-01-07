#!/bin/bash
#
# Avadhi Collector Installation Script
# Mode: systemd timer + template service (NO dispatcher)
#

set -e

# ---------------- Configuration ----------------
INSTALL_DIR="/opt/avadhi-collector"
SERVICE_USER="avadhi"

SCRIPT_SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------- Banner ----------------
echo "--------------------------------------------------"
echo "--- Avadhi Collector Installation Script ---"
echo "Installation Directory : $INSTALL_DIR"
echo "Service User           : $SERVICE_USER"
echo "Expected assets:"
echo "  - avadhi-collector"
echo "  - Config.toml.example"
echo "  - avadhi@.service"
echo "  - avadhi.timer"
echo "--------------------------------------------------"

# ---------------- Step 0: System User ----------------
echo "0. Ensuring system user '$SERVICE_USER' exists..."
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    sudo useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
    echo "   System user '$SERVICE_USER' created."
else
    echo "   System user '$SERVICE_USER' already exists."
fi

# ---------------- Step 1: Install Directory ----------------
echo "1. Setting up installation directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# ---------------- Step 2: Copy Application Files ----------------
echo "2. Copying application files..."
[ -f "$SCRIPT_SOURCE_DIR/avadhi-collector" ] || { echo "FATAL: avadhi-collector binary not found."; exit 1; }
sudo cp -f "$SCRIPT_SOURCE_DIR/avadhi-collector" "$INSTALL_DIR/"

[ -f "$SCRIPT_SOURCE_DIR/Config.toml.example" ] || { echo "FATAL: Config.toml.example not found."; exit 1; }
sudo cp -f "$SCRIPT_SOURCE_DIR/Config.toml.example" "$INSTALL_DIR/"

[ ! -f "$INSTALL_DIR/Config.toml" ] && sudo cp "$INSTALL_DIR/Config.toml.example" "$INSTALL_DIR/Config.toml" && echo "   Config.toml created." || echo "   Config.toml already exists. Skipping."

# Copy uninstall script
if [ -f "$SCRIPT_SOURCE_DIR/uninstall.sh" ]; then
    sudo cp -f "$SCRIPT_SOURCE_DIR/uninstall.sh" "$INSTALL_DIR/"
fi


# ---------------- Step 3: Ownership ----------------
echo "3. Setting ownership to $SERVICE_USER"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"

# ---------------- Step 4: Install systemd Units ----------------
echo "4. Installing systemd units..."
TEMPLATE_UNIT="avadhi@.service"
TIMER_UNIT="avadhi.timer"

for UNIT in "$TEMPLATE_UNIT" "$TIMER_UNIT"; do
    [ -f "$SCRIPT_SOURCE_DIR/$UNIT" ] || { echo "FATAL: Required unit file '$UNIT' not found."; exit 1; }
    sudo cp -f "$SCRIPT_SOURCE_DIR/$UNIT" "/etc/systemd/system/$UNIT"
    echo "   Installed $UNIT"
done

sudo systemctl daemon-reload
sudo systemctl enable "$TIMER_UNIT"
sudo systemctl start "$TIMER_UNIT"

# ---------------- Step 5: Setup Confirmation ----------------
echo
echo "--------------------------------------------------"
echo "Avadhi Collector installation complete."
echo "Next step: user setup for tokens and initial configuration."
echo "You can choose to setup now (interactive) or later."
echo "--------------------------------------------------"

# ---------------- Step 5a: Interactive Setup ----------------
if [ -t 0 ]; then
    PS3="Select option: "
    options=("Setup Now" "Setup Later")
    select opt in "${options[@]}"; do
        case $opt in
            "Setup Now")
                echo "Starting interactive setup..."
                sudo -u "$SERVICE_USER" bash -c "cd $INSTALL_DIR && ./avadhi-collector setup"
                break
                ;;
            "Setup Later")
                echo "Skipping interactive setup."
                [ ! -f "$INSTALL_DIR/AvadhiConfig.toml" ] && \
                    sudo touch "$INSTALL_DIR/AvadhiConfig.toml" && \
                    sudo chown "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR/AvadhiConfig.toml" && \
                    sudo chmod 600 "$INSTALL_DIR/AvadhiConfig.toml"
                break
                ;;
            *)
                echo "Invalid option. Please select 1 or 2."
                ;;
        esac
    done
else
    echo "Non-interactive shell detected. Skipping interactive setup."
    echo "To run interactive setup later, execute:"
    echo "  sudo -u $SERVICE_USER bash -c 'cd $INSTALL_DIR && ./avadhi-collector setup'"
    [ ! -f "$INSTALL_DIR/AvadhiConfig.toml" ] && \
        sudo touch "$INSTALL_DIR/AvadhiConfig.toml" && \
        sudo chown "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR/AvadhiConfig.toml" && \
        sudo chmod 600 "$INSTALL_DIR/AvadhiConfig.toml"
fi

# ---------------- Step 6: Post-Install Verification ----------------
echo
echo "--------------------------------------------------"
echo "Running post-install verification..."
[ -x "$INSTALL_DIR/avadhi-collector" ] && echo "✔ Binary exists and is executable." || echo "❌ Binary missing or not executable!"
[ -f "$INSTALL_DIR/Config.toml" ] && echo "✔ Config.toml found." || echo "❌ Config.toml missing!"
[ -f "$INSTALL_DIR/AvadhiConfig.toml" ] && echo "✔ AvadhiConfig.toml found." || echo "⚠ AvadhiConfig.toml not found. User setup may be required."

TIMER_STATUS=$(systemctl is-active "$TIMER_UNIT")
[ "$TIMER_STATUS" = "active" ] && echo "✔ Timer '$TIMER_UNIT' is active." || echo "⚠ Timer '$TIMER_UNIT' is inactive. Start with: sudo systemctl start $TIMER_UNIT"

echo "Next scheduled run for Avadhi Collector:"
systemctl list-timers "$TIMER_UNIT" --all | awk 'NR==2 {print "   " $1, $2, $3, $4, $5, $6, $7}'

echo
echo "--------------------------------------------------"
echo "✅ Installation finished successfully."
echo "Timer is enabled and will run daily at 10:00 local time."
echo "To check timer: systemctl list-timers | grep avadhi"
echo "To run setup later: sudo -u $SERVICE_USER bash -c 'cd $INSTALL_DIR && ./avadhi-collector setup'"
echo "To run collector now: sudo systemctl start avadhi@default"
echo "To verify the posted data: journalctl -u avadhi@default --since today"
echo "--------------------------------------------------"
