## 💾 Installation on Linux (systemd)

The Avadhi Collector is designed to run persistently in the background using the `systemd` service manager.

### Prerequisites

1.  A PostgreSQL/Supabase database already set up.
2.  Your Supabase URL and Service Role Key (from your Supabase project settings).

### Step-by-Step Guide

1.  **Download the Release:**
    Download the latest `avadhi-linux.tar.gz` from the [GitHub Releases Page].
2.  **Extract the Files:**
    ```bash
    tar -xzvf avadhi-linux.tar.gz
    cd avadhi-linux
    ```
3.  **Configure:**
    Copy the example configuration and add your Supabase credentials:
    ```bash
    cp Config.toml.example Config.toml
    # Use a text editor to update Config.toml with your keys!
    nano Config.toml
    ```
4.  **Install the Service:**
    Run the provided installation script. This script moves the files to `/opt/avadhi/` and registers the systemd service.
    ```bash
    sudo ./install.sh
    ```
5.  **Verify Status:**
    Check that the service is running and enabled on boot:
    ```bash
    sudo systemctl status avadhi.service
    ```
----
6.  **Version Release:**
```bash
git add .
git commit -m "feat: A new version release ; featrues: "
git tag v0.1.0
git push origin v0.1.0
    ```