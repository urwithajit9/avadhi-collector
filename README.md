# 🕒 Avadhi Time Collector – Linux Installation Guide

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.70+-orange)](https://www.rust-lang.org/)

The **Avadhi Time Collector** is a lightweight Rust application that runs as a **scheduled system service** on Linux. It reads system boot/shutdown logs (`wtmp`) to calculate daily work spans and posts them to the
[Avadhi Time Tracker](https://www.avadhi.space/).

The collector is designed to:

* Run **once per day**
* Execute during **working hours (10:00 local time)**
* Recover automatically if the system was powered off
* Require **no background daemon**
* Be robust across shutdowns, weekends, and holidays

---

## 🚀 One-Line Installation (Recommended)

```bash
curl -fsSL https://avadhi.space/install.sh | bash
```

This command:

* Downloads the latest release
* Installs the collector into `/opt/avadhi-collector`
* Installs a **systemd service + timer**
* Enables the timer (not the service directly)

This is the **recommended and professional** distribution method.

---

## 📋 Prerequisites

* Linux distribution using **systemd**
* Internet connectivity
* `sudo` access
* Active account on [https://www.avadhi.space](https://www.avadhi.space)

---

## 📁 Installation Layout

All runtime files are kept together:

```text
/opt/avadhi-collector/
├── avadhi-collector        # Rust binary
├── Config.toml             # Static backend configuration
├── AvadhiConfig.toml       # User tokens (created during setup)
```

Systemd units are installed to:

```text
/etc/systemd/system/
├── avadhi-collector.service
├── avadhi-collector.timer
```

---

## 🔐 Mandatory One-Time Authentication

The collector **cannot run** until user credentials are provided.

### Step 1: Run setup interactively (once)

```bash
cd /opt/avadhi-collector
./avadhi-collector setup
```

This will:

* Open the browser to the login page
* Prompt for:

  * User ID (UUID)
  * Access Token
  * Refresh Token
* Create `AvadhiConfig.toml`

> Run this command as your **normal user**, not with `sudo`.

---

## ⏰ How Execution Works (Important)

* The collector **does not run continuously**
* It is triggered by a **systemd timer**
* Runs **once per day at ~10:00 local time**
* If the system is powered off at 10:00:

  * It runs once on the **next boot**
* Weekends are **included**
* Missed days are **not backfilled**

This matches the intended data model:

> “Finalize yesterday’s work span during the next working window.”

---

## 🔎 Verification (Required)

### 1. Verify timer is enabled

```bash
systemctl status avadhi-collector.timer
```

Expected:

```text
Loaded: loaded
Active: active (waiting)
```

### 2. Verify next scheduled run

```bash
systemctl list-timers | grep avadhi
```

Expected output includes:

* NEXT run time
* LAST run time (after first execution)

### 3. Verify service execution logs

```bash
journalctl -u avadhi-collector.service --since today
```

You should see:

* Successful startup
* API POST confirmation
* Clean exit (oneshot)

---

## 🛠 Troubleshooting

### Tokens expired / unauthorized (401)

Symptom:

```text
API Error: Token unauthorized or expired (401)
```

Fix:

```bash
cd /opt/avadhi-collector
./avadhi-collector setup
```

Then wait for the next scheduled timer run
(or trigger manually for testing):

```bash
sudo systemctl start avadhi-collector.service
```

---

## 📌 Notes

* The service is **timer-driven**, not long-running
* Configuration remains in `/opt/avadhi-collector`
* Safe to install on laptops, desktops, or servers
* Future versions may support always-on systems via sleep-based logic

---

## 🔗 Links

* 🌐 Web App: [https://www.avadhi.space/](https://www.avadhi.space/)
* 📦 Releases: [https://github.com/urwithajit9/avadhi-collector/releases](https://github.com/urwithajit9/avadhi-collector/releases)
* 📘 Documentation: [https://github.com/urwithajit9/avadhi-collector](https://github.com/urwithajit9/avadhi-collector)

---

### Final status

* ✔ Timer-based execution
* ✔ Weekend-safe
* ✔ Non-interactive service
* ✔ Clear verification path
* ✔ Production-grade install flow


---

# 🧹 Avadhi Collector – Uninstall Guide (Linux)

## What this removes

* systemd **service instance** (`avadhi@<user>.service`)
* systemd **timer** (`avadhi.timer`)
* systemd **unit files**
* installed files under `/opt/avadhi-collector`
* all local configuration (`Config.toml`, `AvadhiConfig.toml`)

---

## 1️⃣ Stop and disable systemd units

Run as your normal user (sudo will be invoked where needed).

```bash
USER_NAME=$(whoami)

# Stop & disable service instance
sudo systemctl stop avadhi@$USER_NAME.service 2>/dev/null || true
sudo systemctl disable avadhi@$USER_NAME.service 2>/dev/null || true

# Stop & disable timer
sudo systemctl stop avadhi.timer 2>/dev/null || true
sudo systemctl disable avadhi.timer 2>/dev/null || true
```

---

## 2️⃣ Remove systemd unit files

```bash
# Remove service template
sudo rm -f /etc/systemd/system/avadhi@.service

# Remove timer unit
sudo rm -f /etc/systemd/system/avadhi.timer

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

Verification:

```bash
systemctl list-unit-files | grep avadhi || echo "No avadhi units found"
```

---

## 3️⃣ Remove installed files and configs

```bash
sudo rm -rf /opt/avadhi-collector
```

Verification:

```bash
ls /opt | grep avadhi || echo "/opt/avadhi-collector removed"
```

---

## 4️⃣ (Optional) Remove dedicated system user

⚠️ **Only do this if the user is not used for anything else.**

```bash
sudo userdel -r avadhi
```

Verify:

```bash
id avadhi || echo "User avadhi removed"
```

---

## 5️⃣ Final verification checklist

```bash
# No services
systemctl list-units | grep avadhi || echo "No running units"

# No timers
systemctl list-timers | grep avadhi || echo "No timers scheduled"

# No files
test -d /opt/avadhi-collector || echo "Install directory removed"
```

---

# 🧠 Why this works (design-aligned)

| Component               | Reason                                      |
| ----------------------- | ------------------------------------------- |
| `avadhi@.service`       | Template instance → must remove template    |
| `avadhi.timer`          | System-wide daily scheduler                 |
| `/opt/avadhi-collector` | Single source of truth for binary + configs |
| `daemon-reload`         | Required after removing unit files          |
| `reset-failed`          | Clears stale systemd state                  |

---

## 🔁 Reinstall after uninstall

```bash
curl -fsSL https://avadhi.space/install.sh | bash
```

or

```bash
curl -fsSL https://raw.githubusercontent.com/urwithajit9/avadhi-collector/main/scripts/install-bootstrap.sh | bash
```


