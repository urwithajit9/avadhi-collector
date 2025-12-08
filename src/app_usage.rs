use std::fs;
use std::io;
use std::path::Path;

// The standard clock tick rate (Hz or Jiffies per second) is typically 100 on Linux.
// We define it here for consistent calculation of seconds from jiffies.
// Note: A more robust solution would dynamically call sysconf(_SC_CLK_TCK).
const CLK_TCK: u64 = 100;

/// Structure to hold relevant process data extracted from the /proc filesystem.
#[derive(Debug, Clone)]
pub struct AppProcess {
    pub pid: u32,
    pub command: String,
    // Total time the process has spent executing in user space (in jiffies)
    pub utime: u64,
    // Total time the process has spent executing in kernel space (in jiffies)
    pub stime: u64,
    // The time the process started after system boot (in jiffies)
    pub start_time_jiffies: u64,
}

impl AppProcess {
    /// Calculates the total CPU time consumed by the process in seconds.
    pub fn total_cpu_time_seconds(&self) -> f64 {
        ((self.utime + self.stime) as f64) / (CLK_TCK as f64)
    }

    /// Calculates the process uptime (since boot) in seconds.
    /// This is an estimate based on the system boot time (not measured here) and start_time_jiffies.
    pub fn uptime_seconds(&self, boot_time_jiffies: u64) -> f64 {
        // start_time_jiffies is time since system boot.
        // We use it directly as the uptime for simplicity.
        (self.start_time_jiffies as f64) / (CLK_TCK as f64)
    }
}

/// Parses a single /proc/[PID]/stat file to extract process timing data.
/// Returns Ok(AppProcess) on success, or an error if the file cannot be read or parsed.
fn parse_proc_stat(pid: u32) -> io::Result<AppProcess> {
    let stat_path = format!("/proc/{}/stat", pid);
    let content = fs::read_to_string(stat_path)?;

    // 1. Extract the command name (field 2, enclosed in parentheses)
    // The structure is: PID (COMM) STATE ...
    let start_paren = content.find('(').ok_or(io::Error::new(io::ErrorKind::InvalidData, "Missing start parenthesis"))?;
    let end_paren = content.rfind(')').ok_or(io::Error::new(io::ErrorKind::InvalidData, "Missing end parenthesis"))?;
    let command = content[start_paren + 1 .. end_paren].trim().to_string();

    // 2. Parse the rest of the fields starting after the command name.
    // We split the rest of the string by whitespace.
    // Field indices shift after removing PID and (COMM).
    let remaining_fields: Vec<&str> = content[end_paren + 1..].split_whitespace().collect();

    // Original /proc/stat indices (0-based) mapped to remaining_fields indices:
    // PID (0), (COMM) (1) are gone.
    // utime (13) -> remaining_fields index 11
    // stime (14) -> remaining_fields index 12
    // starttime (21) -> remaining_fields index 19

    let utime: u64 = remaining_fields.get(11).ok_or(io::Error::new(io::ErrorKind::InvalidData, "Missing utime field"))?.parse().unwrap_or(0);
    let stime: u64 = remaining_fields.get(12).ok_or(io::Error::new(io::ErrorKind::InvalidData, "Missing stime field"))?.parse().unwrap_or(0);
    let start_time_jiffies: u64 = remaining_fields.get(19).ok_or(io::Error::new(io::ErrorKind::InvalidData, "Missing starttime field"))?.parse().unwrap_or(0);

    Ok(AppProcess {
        pid,
        command,
        utime,
        stime,
        start_time_jiffies,
    })
}


/// Finds all running process PIDs and attempts to parse their stat file.
/// This is the main public function for the module.
pub fn get_all_active_apps() -> Vec<AppProcess> {
    let mut processes = Vec::new();
    let proc_path = Path::new("/proc");

    // Check if we are on a system that supports /proc (i.e., Linux)
    if !proc_path.exists() {
        eprintln!("Error: /proc filesystem not found. App usage tracking not supported on this OS.");
        return processes;
    }

    if let Ok(entries) = fs::read_dir(proc_path) {
        for entry in entries.filter_map(|e| e.ok()) {
            let file_name = entry.file_name();

            // 1. Filter for numeric directory names (PIDs)
            if let Some(name_str) = file_name.to_str() {
                if let Ok(pid) = name_str.parse::<u32>() {

                    // 2. Attempt to parse the stat file for this PID
                    match parse_proc_stat(pid) {
                        Ok(app) => processes.push(app),
                        Err(_) => {
                            // This is common: process might terminate during iteration, or we might lack permissions.
                            // We quietly ignore the failed parse and move on.
                        }
                    }
                }
            }
        }
    }
    processes
}