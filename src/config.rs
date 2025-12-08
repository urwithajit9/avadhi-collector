use serde::{Serialize, Deserialize};
use std::fs;
use std::io::{self, Write};
use std::path::Path;

pub const ADMIN_CONFIG_PATH: &str = "Config.toml";
pub const USER_CONFIG_PATH: &str = "AvadhiConfig.toml";

// --- Configuration Structs ---
#[derive(Serialize, Deserialize, Default, Debug, Clone)]
pub struct AdminConfig {
    pub web_app_url: Option<String>,
    pub supabase_url: Option<String>,
    pub supabase_anon_key: Option<String>,
}

#[derive(Serialize, Deserialize, Default, Debug, Clone)]
pub struct UserConfig {
    // Stores the authenticated user's UUID (provided by the user during setup)
    pub user_id: Option<String>,
    pub access_token: Option<String>,
    pub refresh_token: Option<String>,

    /// Field used by main.rs to prevent re-posting of historical data.
    /// Stores the date (YYYY-MM-DD) of the last successfully posted day.
    pub last_posted_date: Option<String>, // Made pub for external modification
}

// --- File Handling Functions ---
pub fn load_admin_config() -> AdminConfig {
    let path = Path::new(ADMIN_CONFIG_PATH);
    if path.exists() {
        match fs::read_to_string(path) {
            Ok(contents) => match toml::from_str(&contents) {
                Ok(config) => {
                    println!("Admin configuration loaded successfully from {}.", ADMIN_CONFIG_PATH);
                    config
                },
                Err(e) => {
                    eprintln!("Error parsing {}: {}", ADMIN_CONFIG_PATH, e);
                    AdminConfig::default()
                }
            },
            Err(e) => {
                eprintln!("Error reading {}: {}", ADMIN_CONFIG_PATH, e);
                AdminConfig::default()
            }
        }
    } else {
        eprintln!("Admin configuration file {} not found.", ADMIN_CONFIG_PATH);
        AdminConfig::default()
    }
}

pub fn load_user_config() -> UserConfig {
    let path = Path::new(USER_CONFIG_PATH);
    if path.exists() {
        match fs::read_to_string(path) {
            Ok(contents) => match toml::from_str(&contents) {
                Ok(config) => {
                    println!("User configuration loaded successfully from {}.", USER_CONFIG_PATH);
                    config
                },
                Err(e) => {
                    eprintln!("Error parsing {}: {}", USER_CONFIG_PATH, e);
                    UserConfig::default()
                }
            },
            Err(e) => {
                eprintln!("Error reading {}: {}", USER_CONFIG_PATH, e);
                UserConfig::default()
            }
        }
    } else {
        println!("User configuration file {} not found. Will prompt for login details.", USER_CONFIG_PATH);
        UserConfig::default()
    }
}

/// Serializes and saves the updated UserConfig back to the configuration file.
pub fn save_user_config(user_config: &UserConfig) {
    match toml::to_string_pretty(user_config) { // Using pretty to make the file readable
        Ok(contents) => {
            match fs::write(USER_CONFIG_PATH, contents) {
                Ok(_) => println!("[INFO] User configuration saved successfully to {}.", USER_CONFIG_PATH),
                Err(e) => eprintln!("Error writing to {}: {}", USER_CONFIG_PATH, e),
            }
        }
        Err(e) => eprintln!("Error serializing user config: {}", e),
    }
}


/// Prompts the user for necessary credentials (User ID, Access/Refresh Tokens) and saves them.
pub fn initial_setup_and_login(admin_config: &AdminConfig, user_config: &mut UserConfig) {
    println!("\n--- Avadhi Collector User Setup Required ---");

    let login_url = admin_config.web_app_url.as_deref()
        .unwrap_or("https://avadhi-time-tracker.vercel.app/login (Default - Check Config.toml)");

    println!("\nStep 1: Logging in to Supabase.");
    println!("Browser opened to the login page ({}).", login_url);

    println!("\nStep 2: After logging in via the web app, please copy your User ID, Access Token, and Refresh Token.");

    // Prompt for User ID
    print!("Enter User ID (UUID): ");
    io::stdout().flush().unwrap();
    let mut user_id = String::new();
    io::stdin().read_line(&mut user_id).unwrap();
    user_config.user_id = Some(user_id.trim().to_string());

    // Prompt for Access Token
    print!("Enter Access Token (JWT): ");
    io::stdout().flush().unwrap();
    let mut access_token = String::new();
    io::stdin().read_line(&mut access_token).unwrap();
    user_config.access_token = Some(access_token.trim().to_string());

    // Prompt for Refresh Token
    print!("Enter Refresh Token: ");
    io::stdout().flush().unwrap();
    let mut refresh_token = String::new();
    io::stdin().read_line(&mut refresh_token).unwrap();
    user_config.refresh_token = Some(refresh_token.trim().to_string());


    save_user_config(user_config);
    println!("Tokens saved to {}.", USER_CONFIG_PATH);
}