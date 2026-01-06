# 🕒 Avadhi Time Collector – Linux Installation Guide

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.70+-orange)](https://www.rust-lang.org/)

The **Avadhi Time Collector** is a lightweight Rust application that runs as a **scheduled system service** on Linux.
It reads system boot/shutdown logs (`wtmp`) to calculate daily work spans and posts them to the
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
* Creates a **dedicated system user** (`avadhi`)
* Installs a **systemd service template + timer**
* Enables the **timer only** (the service is never enabled directly)

This is the **recommended and production-grade** installation method.

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
├── avadhi@.service         # Template service (oneshot worker)
├── avadhi.timer            # Daily scheduler
```

> There is **no long-running service** and no dispatcher unit.

---

## 🔐 Mandatory One-Time Authentication

The collector **will not post data** until credentials are provided.

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
systemctl status avadhi.timer
```

Expected:

```text
Loaded: loaded
Active: active (waiting)
```

---

### 2. Verify next scheduled run

```bash
systemctl list-timers | grep avadhi
```

Expected output includes:

* NEXT run time
* LAST run time (after first execution)

---

### 3. Verify execution logs

The timer triggers a transient instance of `avadhi@.service`.

```bash
journalctl -u avadhi@.service --since today
```

You should see:

* Successful startup
* API POST confirmation
* Clean exit (`Type=oneshot`)

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

To test immediately:

```bash
sudo systemctl start avadhi@$(date +%s).service
```

(The timer will resume normal scheduling afterward.)

---

## 📌 Notes

* The service is **timer-driven**, not long-running
* Configuration lives entirely in `/opt/avadhi-collector`
* Safe for laptops, desktops, and servers
* Future versions may support always-on systems via sleep-based logic

---

## 🔗 Links

* 🌐 Web App: [https://www.avadhi.space/](https://www.avadhi.space/)
* 📦 Releases: [https://github.com/urwithajit9/avadhi-collector/releases](https://github.com/urwithajit9/avadhi-collector/releases)
* 📘 Source: [https://github.com/urwithajit9/avadhi-collector](https://github.com/urwithajit9/avadhi-collector)

---

# 🧹 Avadhi Collector – Uninstall Guide (Linux)

The release includes an official uninstall script.

---

## 🚨 What This Removes

* `avadhi.timer`
* `avadhi@.service` (template)
* All instantiated service runs
* `/opt/avadhi-collector`
* Local configuration files
* Dedicated system user (`avadhi`)

---

## ✅ Recommended Uninstall Method

```bash
cd avadhi-linux
./uninstall.sh
```

The script is **safe and idempotent**.

---

## 🔍 Manual Verification (Optional)

```bash
systemctl list-timers | grep avadhi || echo "No timers scheduled"
systemctl list-units | grep avadhi || echo "No running units"
test -d /opt/avadhi-collector || echo "Install directory removed"
id avadhi || echo "System user removed"
```

---

## 🔁 Reinstall

```bash
curl -fsSL https://avadhi.space/install.sh | bash
```

or

```bash
curl -fsSL https://raw.githubusercontent.com/urwithajit9/avadhi-collector/main/scripts/install-bootstrap.sh | bash
```

---

## ✅ Final Status

* ✔ Timer-based execution
* ✔ Dedicated system user
* ✔ Weekend-safe
* ✔ No daemon process
* ✔ Clean install / uninstall
* ✔ Production-ready

---


