mod config;
mod api;

// --- Imports for Data Parsing and Time Calculations ---
use chrono::{DateTime, Duration, Local, NaiveDateTime, TimeZone, NaiveDate};
use std::{collections::HashMap, process::Command};
use regex::Regex;
use anyhow::{anyhow, Result};
// --- End Data Parsing Imports ---

use crate::config::{load_admin_config, load_user_config, initial_setup_and_login, AdminConfig, UserConfig, save_user_config};
use crate::api::{post_work_span, WorkSpanData};
use tokio;


// --- Internal Data Structures & Constants ---
/// Represents a single boot/shutdown record for aggregation.
#[derive(Debug, Clone)]
struct SessionRecord {
    start_time: DateTime<Local>,
    end_time: DateTime<Local>,
}

/// Constant for parsing the output format of the 'last' command
const LAST_DATE_FORMAT: &str = "%a %b %d %H:%M:%S %Y";

// --- Data Parsing Functions (UNCHANGED) ---

/// Executes the 'last' command and parses raw output into structured session records.
async fn fetch_last_logs() -> Result<Vec<SessionRecord>> {
    println!("[INFO] Executing 'last -x -F reboot' to fetch logs...");

    let output = tokio::task::spawn_blocking(|| {
        Command::new("last")
            .args(&["-x", "-F", "reboot"])
            .output()
    }).await
    .map_err(|e| anyhow!("Task failed to join: {}", e))?
    .map_err(|e| anyhow!("I/O Error executing 'last': {}", e))?;

    let stdout = String::from_utf8(output.stdout).map_err(|e| anyhow!("UTF-8 Decoding Error: {}", e))?;
    let mut sessions = Vec::new();

    // Regex to capture start time and optional end time
    let re = Regex::new(r"reboot\s+system boot\s+.*?\s+([A-Z][a-z]{2}\s+[A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(?:-\s+([A-Z][a-z]{2}\s+[A-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}\s+\d{4})|still running)")
        .map_err(|e| anyhow!("Regex Error: {}", e))?;

    for line in stdout.lines() {
        if let Some(caps) = re.captures(line) {
            let start_str = caps.get(1).map_or("", |m| m.as_str());
            let end_str_opt = caps.get(2).map(|m| m.as_str());

            // Parse Start Time as local time
            let start_dt_naive = NaiveDateTime::parse_from_str(start_str, LAST_DATE_FORMAT)
                                .map_err(|e| anyhow!("Chrono Parse Error (Start): {}", e))?;

            let start_dt_local = Local
                .from_local_datetime(&start_dt_naive)
                .single()
                .ok_or_else(|| anyhow!("Date conversion failed for start time"))?;

            // Determine End Time
            let end_dt_local = match end_str_opt {
                Some(end_str) => {
                    let end_dt_naive = NaiveDateTime::parse_from_str(end_str, LAST_DATE_FORMAT)
                        .map_err(|e| anyhow!("Chrono Parse Error (End): {}", e))?;

                    Local
                        .from_local_datetime(&end_dt_naive)
                        .single()
                        .ok_or_else(|| anyhow!("Date conversion failed for end time"))?
                },
                None => Local::now(), // "still running" means current time
            };

            if start_dt_local <= end_dt_local {
                sessions.push(SessionRecord {
                    start_time: start_dt_local,
                    end_time: end_dt_local,
                });
            }
        }
    }

    println!("[INFO] Successfully parsed {} raw sessions.", sessions.len());
    Ok(sessions)
}

/// Calculates the Earliest Boot/Latest Shutdown span for each calendar day,
/// and converts the data into the format required by the API (WorkSpanData).
fn calculate_spans(sessions: Vec<SessionRecord>) -> Result<Vec<WorkSpanData>> {

    // Key: NaiveDate | Value: (min_start, max_end)
    let mut daily_data: HashMap<chrono::NaiveDate, (DateTime<Local>, DateTime<Local>)> = HashMap::new();

    for session in sessions {
        let date = session.start_time.date_naive();
        let end_date = session.end_time.date_naive();

        // 1. Update Span for Start Date
        let entry = daily_data.entry(date)
            .or_insert_with(|| (session.start_time, session.end_time));

        if session.start_time < entry.0 {
            entry.0 = session.start_time; // Earliest Start
        }
        if session.end_time > entry.1 {
            entry.1 = session.end_time; // Latest End
        }

        // 2. If the session crosses midnight, update the span for the end date as well.
        // This handles sessions like 23:00 to 01:00
        if date != end_date {
            let end_entry = daily_data.entry(end_date)
                .or_insert_with(|| (session.end_time, session.end_time));

            if session.end_time > end_entry.1 {
                end_entry.1 = session.end_time;
            }
        }
    }

    // --- Final Calculation and Formatting into WorkSpanData ---
    let mut results = Vec::new();

    for (date, (first_boot, last_shutdown)) in daily_data {
        if last_shutdown <= first_boot {
            continue;
        }

        let span: Duration = last_shutdown - first_boot;
        let total_seconds = span.num_seconds();
        let total_minutes = total_seconds / 60;

        let hours = total_seconds / 3600;
        let remaining_minutes = (total_seconds % 3600) / 60;

        // Format for API: "8h 30m"
        let total_span_formatted = format!("{}h {}m", hours, remaining_minutes);

        results.push(WorkSpanData {
            date: date.format("%Y-%m-%d").to_string(),
            first_boot: first_boot.format("%H:%M:%S").to_string(),
            last_shutdown: last_shutdown.format("%H:%M:%S").to_string(),
            total_span: total_span_formatted,
            total_span_minutes: total_minutes as i32, // Cast from i64 to i32
        });
    }

    Ok(results)
}


/// Filters the calculated WorkSpanData to only include entries newer than or equal to
/// the date stored in the user configuration (last_posted_date).
fn filter_data_for_posting(
    mut historical_data: Vec<WorkSpanData>,
    user_config: &UserConfig,
) -> Vec<WorkSpanData> {

    let last_posted_date = match user_config.last_posted_date.as_ref() {
        Some(date_str) => NaiveDate::parse_from_str(date_str, "%Y-%m-%d").ok(),
        None => None,
    };

    if last_posted_date.is_none() {
        println!("[WARN] No last posted date found in config. Posting all calculated history.");
        return historical_data;
    }

    let filter_date = last_posted_date.unwrap();

    // --- CHANGE 1: Use >= instead of > ---
    // This ensures we always re-post the last recorded day (the "Yesterday" data)
    // to finalize its shutdown time.
    historical_data.retain(|data| {
        if let Ok(data_date) = NaiveDate::parse_from_str(&data.date, "%Y-%m-%d") {
            // Keep data if date is equal to OR greater than the last posted date
            data_date >= filter_date
        } else {
            // Log an error if date parsing fails for an entry, but keep it just in case
            eprintln!("[ERROR] Failed to parse date in historical data: {}", data.date);
            true
        }
    });
    // --- END CHANGE 1 ---

    println!("[INFO] Filtering data to start from or after: {}.", filter_date);


    // Sort by date to ensure we post chronologically (essential for configuration update logic)
    historical_data.sort_by(|a, b| a.date.cmp(&b.date));

    historical_data
}


/// Main entry point for the data collector logic: retrieves data and posts it asynchronously.
async fn run_collector_logic(admin_config: &AdminConfig, user_config: &mut UserConfig) -> Result<()> {

    let current_day_naive = Local::now().date_naive();
    println!("[INFO] Collector running on day: {}", current_day_naive.format("%Y-%m-%d"));

    let sessions = match fetch_last_logs().await {
        Ok(s) => s,
        Err(e) => {
            eprintln!("[FATAL] Failed to retrieve and calculate historical data: {}. Cannot post anything.", e);
            return Err(e.into());
        }
    };

    let all_historical_data = calculate_spans(sessions)?;

    // 1. FILTER: Only process data newer than or equal to the last successful post
    let data_to_post = filter_data_for_posting(all_historical_data, user_config);

    let total_entries = data_to_post.len();

    if total_entries == 0 {
        println!("No new work span data found to post since last run.");
        return Ok(());
    }

    println!("\n[INFO] Starting posting process for {} historical day(s).", total_entries);

    let mut last_successful_date_posted: Option<String> = user_config.last_posted_date.clone();

    for data in data_to_post {
        println!("\n--- Processing data for date: {} ---", data.date);

        // 2. POST: Post the data
        match post_work_span(data.clone(), admin_config, user_config).await {
            Ok(_) => {
                // Determine if this successfully posted date is "Today"
                let posted_date_naive = match NaiveDate::parse_from_str(&data.date, "%Y-%m-%d") {
                    Ok(d) => d,
                    Err(_) => {
                        eprintln!("[ERROR] Failed to parse posted date string '{}'. Skipping config update for safety.", data.date);
                        continue;
                    }
                };

                // --- CHANGE 2: Conditional Config Update ---
                // We only update the config date if the successfully posted data is NOT today.
                // This ensures "Today" is re-posted tomorrow for finalization.
                if posted_date_naive < current_day_naive {
                    last_successful_date_posted = Some(data.date);
                } else {
                    println!("[INFO] Posted data for today ({}). Will NOT update config to this date to ensure finalization tomorrow.", data.date);
                }
                // --- END CHANGE 2 ---
            },
            Err(e) => {
                eprintln!("[ERROR] Failed to post data for date {}: {}. Aborting remaining posts.", data.date, e);
                // If posting fails, we stop the iteration.
                break;
            }
        }
    }

    // 3. UPDATE CONFIG: Persist the last successfully finalized date (which is yesterday or older).
    if user_config.last_posted_date != last_successful_date_posted {
        user_config.last_posted_date = last_successful_date_posted.clone();

        save_user_config(user_config);

        if let Some(date) = last_successful_date_posted {
             println!("\n[SUCCESS] User configuration updated. Last FINALIZED post date is now: {}", date);
        } else {
             println!("\n[INFO] No finalized posts were made in this run, or all posts failed.");
        }
    } else {
        println!("\n[INFO] Last finalized date remains unchanged.");
    }


    println!("\nCollector run finished successfully.");
    Ok(())
}

// --- Main Execution Block (UNCHANGED) ---

fn main() {
    // 1. Load static Admin Configuration
    let admin_config = load_admin_config();

    // 2. Critical check: Ensure AdminConfig has essential values (URL and Key)
    if admin_config.supabase_url.is_none()
        || admin_config.supabase_anon_key.is_none()
        || admin_config.web_app_url.is_none()
    {
        eprintln!("\nFATAL: Critical Admin Configuration (Config.toml) is missing Supabase URL, Anon Key, or Web App URL. Cannot proceed. Please check and set Config.toml.");
        return;
    }

    // 3. Load dynamic User Configuration
    let mut user_config = load_user_config();

    // 4. Check for user token requirement and run interactive setup if tokens are missing.
    if user_config.access_token.is_none()
        || user_config.refresh_token.is_none()
        || user_config.user_id.is_none()
    {
        println!("User configuration missing required fields. Running initial user setup.");
        initial_setup_and_login(&admin_config, &mut user_config);
    }

    // 5. Final check: Ensure user tokens are now present after setup attempt.
    if user_config.access_token.is_none()
        || user_config.refresh_token.is_none()
        || user_config.user_id.is_none()
    {
        eprintln!("\nFATAL: User authentication failed. Access, Refresh tokens, or User ID are still missing. Exiting.");
        return;
    }

    // 6. Start the main runtime loop
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    // Pass both configs to the collector logic
    runtime.block_on(run_collector_logic(&admin_config, &mut user_config))
        .expect("Collector runtime failed unexpectedly.");
}