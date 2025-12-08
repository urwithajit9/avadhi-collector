# 🕒 Avadhi Time Collector - Linux Installation Guide

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.70+-orange)](https://www.rust-lang.org/)

The **Avadhi Time Collector** is a lightweight Rust application that runs as a persistent background service on Linux. It reads your system's boot/shutdown logs (`wtmp`) to calculate daily work spans and posts the data to the [Avadhi Time Tracker web app](https://www.avadhi.space/).

```bash

curl -fsSL https://avadhi.space/install.sh | bash

curl -fsSL https://raw.githubusercontent.com/urwithajit9/avadhi-collector/main/scripts/install-bootstrap.sh | bash

````
### The Benefits

1.  **Simplicity:** Users only have to copy and paste one line into their terminal.
2.  **Automation:** The script handles download, extraction, and running the installer.
3.  **Correct Permissions:** By running the bootstrap script via `bash`, we can control when and how `sudo` is called to run the `install.sh` script, ensuring the correct file permissions and service setup.

This is the recommended and professional way to distribute Linux software. You should update your website's instructions to use this single-line command.

This guide shows how to **install and configure the collector using Systemd**.

---

## 📋 Prerequisites

- Linux distribution with **Systemd** (Ubuntu, Debian, Fedora, Arch, etc.)
- Active user account on [Avadhi Time Tracker](https://www.avadhi.space/)
- Basic terminal knowledge and `sudo` privileges

---

## 🚀 Installation Steps

The installation is divided into **three phases**: preparation, service installation, and user authentication.

---

### Phase 1: Preparation (Download & Extract)

1. **Download** the latest `avadhi-linux.tar.gz` from the GitHub Releases page.
2. **Extract** the archive:

```bash
# Move to your home directory and extract
cd ~
tar -xzvf path/to/avadhi-linux.tar.gz

# Navigate to the extracted folder
cd avadhi-linux
````

---

### Phase 2: Service Installation

The package includes an `install.sh` script to automate setup and install the Systemd service.

1. **Optional**: Review configuration in `Config.toml`.

   * Preconfigured for `https://www.avadhi.space/`.
   * Edit only if using a custom backend.

2. **Run the Installer**:

```bash
# Make script executable
chmod +x install.sh

# Run the installer with sudo
sudo ./install.sh
```

> The installer creates a service instance named:
>
> ```text
> avadhi@yourusername.service
> ```

---

### Phase 3: Mandatory User Authentication

The service starts automatically after installation but will **not post data** until you provide your credentials.

1. **Run the Collector Manually** (as your standard user, **not sudo**):

```bash
cd /opt/avadhi-collector
./avadhi-collector
```

2. **Authenticate**:

* Visit [https://www.avadhi.space/auth](https://www.avadhi.space/auth)
* Retrieve your **User ID (UUID)**, **Access Token (JWT)**, and **Refresh Token**
* Paste the credentials in the terminal prompt

> Once saved, the collector exits automatically.

---

### Final Step: Start the Persistent Service

Restart the service to enable background collection:

```bash
# Identify your service instance
SERVICE_INSTANCE="avadhi@$(whoami).service"
echo "Service Name: $SERVICE_INSTANCE"

# Restart service
sudo systemctl restart $SERVICE_INSTANCE

# Verify status
sudo systemctl status $SERVICE_INSTANCE
```

You should see:

```
Active: active (running)
```

---

## 🛠 Troubleshooting & Logs

View real-time logs:

```bash
sudo journalctl -u avadhi@$(whoami).service -f -n 50
```

<details>
<summary>⚠️ Common Error: Token unauthorized / expired (401)</summary>

If you see `API Error: Token unauthorized or expired (401)`, the service is running but the tokens are invalid.

**Solution**: Re-run the **manual authentication step (Phase 3)** to refresh your credentials.

</details>

---

## 📌 Notes

* The service runs **per user**, so multiple users need separate instances.
* Configurations are stored in `/opt/avadhi-collector/AvadhiConfig.toml`.
* Designed for **long-term, continuous monitoring** of system work spans.

---

## 🔗 Useful Links

* [Avadhi Web App](https://www.avadhi.space/)
* [GitHub Releases](https://github.com/your-repo/avadhi-time-collector/releases)




