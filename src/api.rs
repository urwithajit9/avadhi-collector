use reqwest::{Client, header, StatusCode};
use serde_json::{json, Value};
use anyhow::{anyhow, Result}; // Used for simplified, public error handling
use crate::config::{Config, save_config, initial_setup_and_login};
use std::fmt::Debug;

// === CONSTANTS ===
const SUPABASE_URL: &str = "https://lqfvugvggwrdrsuwnbey.supabase.co"; 
const TABLE_NAME: &str = "daily_work_span";

// === DATA STRUCTURE ===
#[derive(Debug, Clone)]
pub struct WorkSpanData {
    pub date: String,
    pub total_span_minutes: i32,
    pub total_span: String,
    pub first_boot: String,
    pub last_shutdown: String,
}

// === API CALLS ===

/// Refreshes the Access Token using the stored Refresh Token.
/// Returns anyhow::Result<()>
async fn refresh_access_token(config: &mut Config) -> Result<()> {
    println!("\nAttempting to refresh expired access token...");
    
    let refresh_token = match config.refresh_token.as_ref() {
        Some(token) => token,
        None => {
            eprintln!("Refresh token is missing. Cannot automatically refresh.");
            return Err(anyhow!("Missing refresh token in configuration."));
        }
    };
    
    let url = format!("{}/auth/v1/token?grant_type=refresh_token", SUPABASE_URL);
    let client = Client::new();

    let payload = json!({
        "refresh_token": refresh_token,
    });

    let res = client.post(&url)
        .header(header::CONTENT_TYPE, "application/json")
        .json(&payload)
        .send()
        .await?; // Reqwest error handling via '?'

    if res.status().is_success() {
        let body: Value = res.json().await?; // JSON parsing error handling via '?'
        
        let new_access_token = body["access_token"].as_str().map(|s| s.to_string());
        let new_refresh_token = body["refresh_token"].as_str().map(|s| s.to_string());

        if let (Some(new_access), Some(new_refresh)) = (new_access_token, new_refresh_token) {
            config.access_token = Some(new_access);
            config.refresh_token = Some(new_refresh);
            save_config(config);
            println!("Tokens successfully refreshed and saved.");
            Ok(())
        } else {
            // Use anyhow! for structure-related error
            Err(anyhow!("Token refresh failed: response from Supabase was malformed (missing tokens)."))
        }
    } else {
        let status = res.status();
        let body = res.text().await.unwrap_or_else(|_| String::from("No response body"));
        eprintln!("Refresh API Error: Status {} - Response: {}", status, body);
        // Use anyhow! for network/API related error
        Err(anyhow!("Failed to refresh token: Status {}", status))
    }
}


/// Posts the work span data, handling token expiration with a refresh attempt.
/// Returns anyhow::Result<()>
pub async fn post_work_span(data: WorkSpanData, config: &mut Config) -> Result<()> {
    
    let data_to_post = data;

    // Use a loop to retry the operation after a token refresh, avoiding recursion.
    loop {
        // 1. Authentication Check
        let access_token = match config.access_token.as_ref() {
            Some(token) => token,
            None => {
                eprintln!("Access token missing. Cannot proceed with posting data. Running initial setup.");
                initial_setup_and_login(config);
                // If the setup didn't work, we exit. If it did, the config is updated, and the loop continues.
                if config.access_token.is_none() {
                    return Err(anyhow!("Authentication failed and tokens are still missing after setup."));
                }
                // Continue the loop to use the newly acquired token
                continue; 
            }
        };
        
        // 2. Prepare Request
        let client = Client::new();
        let url = format!("{}/rest/v1/{}", SUPABASE_URL, TABLE_NAME);
        let auth_value = format!("Bearer {}", access_token);

        let mut headers = header::HeaderMap::new();
        headers.insert(
            header::AUTHORIZATION,
            header::HeaderValue::from_str(&auth_value).map_err(|e| anyhow!("Invalid token header: {}", e))?,
        );
        headers.insert(
            header::CONTENT_TYPE,
            header::HeaderValue::from_static("application/json"),
        );

        let payload = json!({
            "date": data_to_post.date,
            "total_span_minutes": data_to_post.total_span_minutes,
            "total_span": data_to_post.total_span,
            "first_boot": data_to_post.first_boot,
            "last_shutdown": data_to_post.last_shutdown,
        });
        
        println!("Attempting to post data to Supabase...");

        // 3. Send Request
        let res = client.post(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await?; 

        // 4. Process Response
        match res.status() {
            // Success status
            s if s.is_success() => {
                println!("Successfully posted data. Status: {}", s);
                return Ok(()); // Success! Exit the loop and function.
            },
            
            // Unauthorized/Expired Token
            StatusCode::UNAUTHORIZED => {
                eprintln!("API Error: Token unauthorized or expired (401).");
                

                // Attempt Refresh Token workflow
                match refresh_access_token(config).await {
                    Ok(_) => {
                        println!("Token refreshed successfully. Retrying data post...");
                        // Use continue to restart the loop with the new token
                        continue; 
                    },
                    Err(e) => {
                        // If refresh fails, try manual login
                        eprintln!("Automatic token refresh failed: {}. Attempting manual re-authentication.", e);
                        initial_setup_and_login(config);
                        
                        // Check if manual login provided new tokens
                        if config.access_token.is_some() {
                            println!("Manual re-authentication succeeded. Retrying...");
                            continue;
                        } else {
                            // Manual login failed. Fail finally.
                            return Err(anyhow!("Failed to automatically refresh token and manual re-authentication also failed."));
                        }
                    }
                }
            },
            
            // Other errors
            s => {
                let body = res.text().await.unwrap_or_else(|_| String::from("No response body"));
                eprintln!("API Error: Status {} - Response: {}", s, body);
                // Convert status and response body into a clear anyhow error
                return Err(anyhow!("Supabase API failed with status {}: {}", s, body));
            }
        }
    }
}