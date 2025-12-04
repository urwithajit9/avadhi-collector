mod config;
mod api;

use crate::config::{load_config, initial_setup_and_login};
use crate::api::{post_work_span, WorkSpanData};
use tokio;
use anyhow::Result; // Import Result from anyhow

fn main() {
    // 1. Load configuration (or default if missing)
    let mut config = load_config();

    // 2. Check for initial setup requirement (Missing tokens)
    if config.access_token.is_none() || config.refresh_token.is_none() {
        println!("Configuration missing required tokens. Running initial setup.");
        initial_setup_and_login(&mut config);
    }
    
    // Final check before runtime: if tokens are still missing, we cannot proceed.
    if config.access_token.is_none() || config.refresh_token.is_none() {
        eprintln!("\nFATAL: Authentication tokens are missing or setup failed. Exiting.");
        return;
    }

    // 3. Start the main runtime loop
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    // The runtime handles the Result from run_collector_logic
    runtime.block_on(run_collector_logic(&mut config))
        .expect("Collector runtime failed unexpectedly.");
}


/// Example function simulating the collector's daily run (e.g., on shutdown event)
async fn run_collector_logic(config: &mut config::Config) -> Result<()> {
    // This function returns Result<()>, allowing us to use '?' for easy error propagation
    
    // Mock data structure to simulate system detection
    let mock_data = WorkSpanData {
        date: "2025-12-05".to_string(), // New day
        total_span_minutes: 480, // 8 hours
        total_span: "8h 0m".to_string(),
        first_boot: "09:00:00".to_string(),
        last_shutdown: "17:00:00".to_string(),
    };

    // Use '?' to propagate errors from the posting function
    post_work_span(mock_data, config).await?; 
    
    println!("Collector run finished successfully.");
    Ok(())
}