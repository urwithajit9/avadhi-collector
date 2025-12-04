use serde::{Serialize, Deserialize};
use std::{fs, io::{self, Write}};
use toml;

pub const CONFIG_FILE_PATH: &str = "AvadhiConfig.toml";
pub const WEB_APP_URL: &str = "YOUR_AVADHI_WEB_APP_URL/login"; // ⚠️ REPLACE THIS

/// Configuration structure to save to the TOML file.
#[derive(Serialize, Deserialize, Debug, Default, Clone)]
pub struct Config {
    /// Short-lived token used for daily data API calls.
    pub access_token: Option<String>, 
    /// Long-lived token used to acquire new access_tokens.
    pub refresh_token: Option<String>, 
}

/// Loads the configuration from the TOML file.
pub fn load_config() -> Config {
    match fs::read_to_string(CONFIG_FILE_PATH) {
        Ok(contents) => {
            match toml::from_str(&contents) {
                Ok(config) => config,
                Err(e) => {
                    eprintln!("Warning: Could not parse {}. Creating new config. Error: {}", CONFIG_FILE_PATH, e);
                    Config::default()
                }
            }
        },
        Err(_) => {
            // File not found, likely a first run
            Config::default()
        }
    }
}

/// Saves the current configuration state to the TOML file.
pub fn save_config(config: &Config) {
    let toml_string = match toml::to_string(config) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error: Could not serialize config. {}", e);
            return;
        }
    };
    match fs::write(CONFIG_FILE_PATH, toml_string) {
        Ok(_) => println!("Configuration saved successfully."),
        Err(e) => eprintln!("Error: Could not write config to {}. {}", CONFIG_FILE_PATH, e),
    }
}

/// Handles the interactive setup for the user (first run or token expired).
pub fn initial_setup_and_login(config: &mut Config) {
    println!("\n--- Avadhi Authentication Required ---");
    println!("Step 1: Logging in to Supabase.");

    if let Err(e) = opener::open(WEB_APP_URL) {
        eprintln!("Could not automatically open browser. Please navigate to: {}", WEB_APP_URL);
        eprintln!("Error: {}", e);
    } else {
        println!("Browser opened to the login page ({}).", WEB_APP_URL);
    }

    println!("\nStep 2: After logging in via the web app, please copy BOTH your Access Token and Refresh Token.");
    println!("(The web app must display these tokens in a secure settings page.)");
    
    // Prompt for Access Token
    print!("\nEnter Access Token (JWT): ");
    io::stdout().flush().unwrap();
    let mut input = String::new();
    if io::stdin().read_line(&mut input).is_ok() {
        config.access_token = Some(input.trim().to_string());
    }
    
    // Prompt for Refresh Token
    input.clear();
    print!("Enter Refresh Token: ");
    io::stdout().flush().unwrap();
    if io::stdin().read_line(&mut input).is_ok() {
        config.refresh_token = Some(input.trim().to_string());
    }

    if config.access_token.is_some() && config.refresh_token.is_some() {
        save_config(config);
        println!("Tokens saved. You can now use the collector.");
    } else {
        eprintln!("\nSetup failed: Missing one or both tokens. Please try again.");
    }
}