# 🕒 Avadhi Time Collector – Linux Installation Guide

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.70+-orange)](https://www.rust-lang.org/)

The **Avadhi Time Collector** is a lightweight Rust application that runs as a **scheduled system service** on Linux.
It reads system boot/shutdown logs (`wtmp`) to calculate daily work spans and posts them to the [Avadhi Time Tracker](https://www.avadhi.space/).

The collector is designed to:

* Run **once per day**
* Execute during **working hours (~10:00 local time)**
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

---

## 📋 Prerequisites

* Linux distribution using **systemd**
* Internet connectivity
* `sudo` access
* Active account on [https://www.avadhi.space](https://www.avadhi.space)

---

## 📁 Installation Layout

```text
/opt/avadhi-collector/
├── avadhi-collector        # Rust binary
├── Config.toml             # Static backend configuration
├── AvadhiConfig.toml       # User tokens and last_posted_date
```

Systemd units:

```text
/etc/systemd/system/
├── avadhi@.service         # Template service (oneshot)
├── avadhi.timer            # Daily scheduler
```

> There is **no long-running service** and no dispatcher unit.

---

## 🔧 Setup Modes

During installation, the collector supports **two modes**:

1. **Setup Now** – Interactive setup immediately collects credentials:

   ```bash
   cd /opt/avadhi-collector
   ./avadhi-collector setup
   ```

   The script will prompt for:

   * User ID (UUID)
   * Access Token
   * Refresh Token
   * Optional: Last posted date for historical data backfill (`YYYY-MM-DD`)

   This mode is **recommended for first-time users**.

2. **Setup Later** – Installer creates `AvadhiConfig.toml` with proper permissions.
   You can edit the file manually:

   ```bash
   sudo nano /opt/avadhi-collector/AvadhiConfig.toml
   sudo chown avadhi:avadhi /opt/avadhi-collector/AvadhiConfig.toml
   sudo chmod 600 /opt/avadhi-collector/AvadhiConfig.toml
   ```

> Installer always ensures proper ownership (`avadhi`) and secure permissions (`600`) even if setup is deferred.

---

## 🔐 last_posted_date Field

`AvadhiConfig.toml` now supports a field:

```toml
last_posted_date = "YYYY-MM-DD"
```

Usage:

* **First-time installation, no historical posts** → leave empty, all historical data will be posted.
* **Existing installation with prior posts** → set to a recent date (1–2 days before last posted) to prevent duplicate submissions and allow safe backfill.

---

## ⏰ How Execution Works

* The collector **does not run continuously**
* Triggered by **systemd timer**
* Runs **once per day at ~10:00 local time**
* If the system is off at 10:00 → executes once on next boot
* Weekends are **included**
* Missed days are **not automatically backfilled** (use `last_posted_date` for controlled backfill)

---

## 🔎 Verification

### 1. Check timer

```bash
systemctl status avadhi.timer
```

Expected:

```text
Loaded: loaded
Active: active (waiting)
```

### 2. Next scheduled run

```bash
systemctl list-timers | grep avadhi
```

Shows NEXT and LAST run times.

### 3. Execution logs

```bash
journalctl -u avadhi@.service --since today
```

---

## 🛠 Troubleshooting

### Missing / expired tokens

```text
API Error: Token unauthorized or expired (401)
```

Fix:

```bash
cd /opt/avadhi-collector
./avadhi-collector setup
```

Test immediately:

```bash
sudo systemctl start avadhi@$(date +%s).service
```

---

## 🧹 Uninstall Guide

```bash
cd avadhi-linux
./uninstall.sh
```

Removes:

* `avadhi.timer`
* `avadhi@.service` (template)
* `/opt/avadhi-collector`
* Local configuration files
* Dedicated system user (`avadhi`)

Verification:

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
* ✔ Interactive / deferred setup modes
* ✔ Dedicated system user
* ✔ Weekend-safe
* ✔ No daemon process
* ✔ Historical backfill support via `last_posted_date`
* ✔ Clean install / uninstall
* ✔ Production-ready


##  How to trigger Avadhi **manually**

### Option A — Trigger via systemd (recommended)

This mirrors real execution:

```bash
sudo systemctl start avadhi@default
```

Then check logs:

```bash
journalctl -u avadhi@default --since today
```

This works **only if** `avadhi@.service` exists.

---

### Option B — Direct binary execution (debug only)

Run exactly what systemd would run:

```bash
sudo -u avadhi /opt/avadhi-collector/avadhi-collector
```








