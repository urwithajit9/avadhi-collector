use chrono::{DateTime, Duration, Local, NaiveDateTime, NaiveTime, Utc, TimeZone};
use serde::{Serialize, Deserialize};
use std::{collections::HashMap, process::Command};
use regex::Regex;
use reqwest::Client;
use tokio::time::sleep;

// --- Data Structures ---

#[derive(Debug, Deserialize)]
pub struct Config {
    pub supabase_url: String,
    pub supabase_service_role_key: String,
    pub supabase_table: String,
    pub daily_check_hour: u32,
    pub daily_check_minute: u32,
}

/// Represents a single boot/shutdown record for aggregation.
#[derive(Debug, Clone)]
struct SessionRecord {
    start_time: DateTime<Local>,
    end_time: DateTime<Local>,
}

/// The final structure representing the calculated span for a single day.
#[derive(Debug, Serialize, Clone)]
pub struct DailySpanData {
    // Use RFC3339 format for ISO 8601 timestamp
    #[serde(serialize_with = "serialize_datetime")]
    pub timestamp: DateTime<Utc>,
    pub date: String,
    pub first_boot: String,
    pub last_shutdown: String,
    pub total_span: String,
    pub total_span_minutes: i64,
}

// Custom serializer for DateTime to ISO 8601 format
fn serialize_datetime<S>(dt: &DateTime<Utc>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: serde::Serializer,
{
    serializer.serialize_str(&dt.to_rfc3339())
}

// --- Constants ---
const LAST_DATE_FORMAT: &str = "%a %b %d %H:%M:%S %Y";

// --- Error Handling ---
#[derive(thiserror::Error, Debug)]
enum AvadhiError {
    #[error("I/O Error: {0}")]
    Io(#[from] std::io::Error),
    #[error("UTF-8 Decoding Error: {0}")]
    Utf8(#[from] std::string::FromUtf8Error),
    #[error("Regex Error: {0}")]
    Regex(#[from] regex::Error),
    #[error("Chrono Parse Error: {0}")]
    Chrono(#[from] chrono::ParseError),
    #[error("Reqwest HTTP Error: {0}")]
    Reqwest(#[from] reqwest::Error),
    #[error("System time error: {0}")]
    Time(#[from] std::time::SystemTimeError),
    #[error("Configuration Error: {0}")]
    Config(#[from] config::ConfigError),
    #[error("Supabase API Error: Status {status}, Body: {body}")]
    SupabaseApi { status: reqwest::StatusCode, body: String },
    #[error("Date conversion failed")]
    DateConversion,
}

// --- Main Logic Functions ---

/// Executes the 'last' command and parses raw output into structured session records.
async fn fetch_last_logs() -> Result<Vec<SessionRecord>, AvadhiError> {
    println!("[INFO] Executing 'last -x -F reboot' to fetch logs...");

    let output = tokio::task::spawn_blocking(|| {
        Command::new("last")
            .args(&["-x", "-F", "reboot"])
            .output()
    }).await
    .expect("Task failed to join")?;

    let stdout = String::from_utf8(output.stdout)?;
    let mut sessions = Vec::new();

    let re = Regex::new(r"reboot\s+system boot\s+.*?\s+([A-Z][a-z]{2}\s+[A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(?:-\s+([A-Z][a-z]{2}\s+[A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}\s+\d{4})|still running)")?;

    for line in stdout.lines() {
        if let Some(caps) = re.captures(line) {
            let start_str = caps.get(1).map_or("", |m| m.as_str());
            let end_str_opt = caps.get(2).map(|m| m.as_str());

            // Parse Start Time as local time
            let start_dt_naive = NaiveDateTime::parse_from_str(start_str, LAST_DATE_FORMAT)
                                .map_err(AvadhiError::Chrono)?;

            // Note: The `last` command output is in local time, not UTC
            // We need to parse it as local time
            let start_dt_local = Local
                .from_local_datetime(&start_dt_naive)
                .single()
                .ok_or(AvadhiError::DateConversion)?;

            // Determine End Time
            let end_dt_local = match end_str_opt {
                Some(end_str) => {
                    let end_dt_naive = NaiveDateTime::parse_from_str(end_str, LAST_DATE_FORMAT)?;
                    Local
                        .from_local_datetime(&end_dt_naive)
                        .single()
                        .ok_or(AvadhiError::DateConversion)?
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

/// Calculates the Earliest Boot/Latest Shutdown span for each calendar day.
fn calculate_spans(sessions: Vec<SessionRecord>) -> Result<Vec<DailySpanData>, AvadhiError> {
    use chrono::LocalResult;

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
        if date != end_date {
            let end_entry = daily_data.entry(end_date)
                .or_insert_with(|| (session.end_time, session.end_time));

            if session.end_time > end_entry.1 {
                end_entry.1 = session.end_time;
            }
        }
    }

    // --- Final Calculation and Formatting ---
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

        // Create timestamp for the date (start of day in local time, converted to UTC)
        let local_dt_start = date.and_time(NaiveTime::from_hms_opt(0, 0, 0).ok_or(AvadhiError::DateConversion)?);

        let local_timestamp = match local_dt_start.and_local_timezone(Local) {
            LocalResult::Single(dt) => dt,
            _ => first_boot,
        };

        let timestamp = local_timestamp.with_timezone(&Utc);

        results.push(DailySpanData {
            timestamp,
            date: date.format("%Y-%m-%d").to_string(),
            first_boot: first_boot.format("%H:%M:%S").to_string(),
            last_shutdown: last_shutdown.format("%H:%M:%S").to_string(),
            total_span: format!("{}.{:02}", hours, remaining_minutes),
            total_span_minutes: total_minutes,
        });
    }

    Ok(results)
}

/// Sends data to Supabase using the REST API via bulk UPSERT.
async fn send_data_to_supabase(config: &Config, data: &[DailySpanData]) -> Result<(), AvadhiError> {
    if data.is_empty() {
        println!("[INFO] No new data to send to Supabase.");
        return Ok(());
    }

    let url = format!("{}/rest/v1/{}?on_conflict=date", config.supabase_url, config.supabase_table);
    let client = Client::new();

    println!("[INFO] Sending {} records to Supabase: {}", data.len(), url);

    let response = client.post(&url)
        .header("apikey", &config.supabase_service_role_key)
        .header("Authorization", format!("Bearer {}", &config.supabase_service_role_key))
        .header("Prefer", "resolution=merge-duplicates")
        .json(&data)
        .send()
        .await?;

    if response.status().is_success() {
        println!("[SUCCESS] Data successfully UPSERTED to Supabase.");
        Ok(())
    } else {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        Err(AvadhiError::SupabaseApi { status, body })
    }
}

// --- Main Execution ---

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Load Configuration
    let config = config::Config::builder()
        .add_source(config::File::with_name("Config"))
        .build()?
        .try_deserialize::<Config>()?;

    println!("--- Avadhi Collector (Duration Tracker) Starting ---");

    // --- PHASE 1: INITIAL FULL HISTORY SYNC ---
    println!("\n[PHASE 1A: Initial History Sync]");
    match fetch_last_logs().await {
        Ok(initial_sessions) => {
            let initial_data = calculate_spans(initial_sessions)?;
            println!("[INFO] Calculated {} historical days of data.", initial_data.len());
            // Send ALL data via bulk UPSERT
            send_data_to_supabase(&config, &initial_data).await?;
        },
        Err(e) => {
            eprintln!("[ERROR] Initial History Sync Failed: {}", e);
        }
    }

    // --- PHASE 2: PERSISTENT DAILY LOOP ---
    println!("\n[PHASE 1B: Starting Persistent Daily Loop]");

    loop {
        let now = Local::now();
        let today = now.date_naive();

        // Define the next check time
        let check_time = NaiveTime::from_hms_opt(config.daily_check_hour, config.daily_check_minute, 0)
                            .unwrap_or(NaiveTime::from_hms_opt(1, 0, 0).unwrap());

        let mut next_check = today.and_time(check_time);

        // If the check time has already passed today, schedule for tomorrow
        if now.time() >= check_time {
            next_check = next_check + Duration::days(1);
        }

        let wait_duration = (next_check - now.naive_local()).to_std()?;

        println!("[SCHEDULE] Waiting until {} for the next daily check...", next_check.format("%Y-%m-%d %H:%M:%S"));
        sleep(wait_duration).await;

        println!("\n[TASK] Running daily log check...");

        // Re-fetch all logs and send the full dataset.
        match fetch_last_logs().await {
            Ok(latest_sessions) => {
                let latest_data = calculate_spans(latest_sessions)?;

                if let Err(e) = send_data_to_supabase(&config, &latest_data).await {
                     eprintln!("[ERROR] Daily Supabase Send Failed: {}", e);
                }
            },
            Err(e) => {
                eprintln!("[ERROR] Daily Log Fetch/Calculation Failed: {}", e);
            }
        }
    }
}