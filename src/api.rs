use reqwest::{Client, header, StatusCode};
use serde_json::{json, Value};
use anyhow::{anyhow, Result};
use crate::config::{AdminConfig, UserConfig, save_user_config, initial_setup_and_login};
use std::fmt::Debug;
use tokio::time::{sleep, Duration}; // Added tokio time for delays

// === CONSTANTS ===
const TABLE_NAME: &str = "daily_work_span";
const MAX_RETRIES: u8 = 3; // Max attempts for transient errors

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
async fn refresh_access_token(admin_config: &AdminConfig, user_config: &mut UserConfig) -> Result<()> {
    println!("\nAttempting to refresh expired access token...");

    let refresh_token = user_config.refresh_token.as_ref()
        .ok_or_else(|| anyhow!("Refresh token is missing. Cannot refresh."))?;
    let supabase_url = admin_config.supabase_url.as_ref()
        .ok_or_else(|| anyhow!("Admin config error: Supabase URL is missing."))?;
    let supabase_anon_key = admin_config.supabase_anon_key.as_ref()
        .ok_or_else(|| anyhow!("Admin config error: Supabase Anon Key is missing."))?;

    let url = format!(
        "{}/auth/v1/token?grant_type=refresh_token&apikey={}",
        supabase_url,
        supabase_anon_key
    );

    let client = Client::new();

    let payload = json!({ "refresh_token": refresh_token, });

    let res = client.post(&url)
        .header(header::CONTENT_TYPE, "application/json")
        .json(&payload)
        .send()
        .await?;

    if res.status().is_success() {
        let body: Value = res.json().await?;

        let new_access_token = body["access_token"].as_str().map(|s| s.to_string());
        let new_refresh_token = body["refresh_token"].as_str().map(|s| s.to_string());

        if let (Some(new_access), Some(new_refresh)) = (new_access_token, new_refresh_token) {
            user_config.access_token = Some(new_access);
            user_config.refresh_token = Some(new_refresh);
            // User ID is NOT fetched here, it must be provided at setup.
            save_user_config(user_config);
            println!("Tokens successfully refreshed and saved.");
            Ok(())
        } else {
            Err(anyhow!("Token refresh failed: response from Supabase was malformed (missing tokens)."))
        }
    } else {
        let status = res.status();
        let body = res.text().await.unwrap_or_else(|_| String::from("No response body"));
        eprintln!("Refresh API Error: Status {} - Response: {}", status, body);
        Err(anyhow!("Failed to refresh token: Status {}", status))
    }
}


/// Posts the work span data, handling token expiration with a refresh attempt.
pub async fn post_work_span(data: WorkSpanData, admin_config: &AdminConfig, user_config: &mut UserConfig) -> Result<()> {

    let data_to_post = data;
    let mut retries = 0; // Initialize retry counter

    loop {
        // 1. Authentication Check & Config Retrieval

        // --- Get all required config values ---
        let access_token = match user_config.access_token.as_ref() {
            Some(token) => token,
            None => {
                eprintln!("Access token missing. Cannot proceed with posting data. Running initial user setup.");
                // initial_setup_and_login will populate tokens and user_id via prompt
                initial_setup_and_login(admin_config, user_config);
                if user_config.access_token.is_none() {
                    return Err(anyhow!("Authentication failed and tokens are still missing after setup."));
                }
                continue;
            }
        };

        // *** HIGHLIGHT: Ensure User ID is present (it must be from the prompt) ***
        let user_id = match user_config.user_id.as_ref() {
            Some(id) => id,
            None => {
                // If user_id is missing, it means the config is incomplete. Re-run setup.
                eprintln!("User ID missing in config. Running initial user setup to collect User ID.");
                initial_setup_and_login(admin_config, user_config);
                // If setup still doesn't provide it, we exit on next loop iteration's access_token check,
                // but for now, we continue and let the setup resolve it.
                continue;
            }
        };
        // -----------------------------------------------------------------------

        let supabase_url = match admin_config.supabase_url.as_ref() {
            Some(url) => url,
            None => return Err(anyhow!("Admin config error: Supabase URL is missing. Cannot post data."))
        };
        let supabase_anon_key = match admin_config.supabase_anon_key.as_ref() {
            Some(key) => key,
            None => return Err(anyhow!("Admin config error: Supabase Anon Key is missing. Cannot post data."))
        };
        // ------------------------------------------

        // 2. Prepare Request
        let client = Client::new();
        let url = format!("{}/rest/v1/{}", supabase_url, TABLE_NAME);

        let auth_value = format!("Bearer {}", access_token);

        let mut headers = header::HeaderMap::new();

        headers.insert(
            header::AUTHORIZATION,
            header::HeaderValue::from_str(&auth_value).map_err(|e| anyhow!("Invalid token header: {}", e))?,
        );
        headers.insert(
            "apikey",
            header::HeaderValue::from_str(supabase_anon_key).map_err(|e| anyhow!("Invalid apikey header: {}", e))?,
        );
        headers.insert(
            header::CONTENT_TYPE,
            header::HeaderValue::from_static("application/json"),
        );
        headers.insert(
            "Prefer",
            header::HeaderValue::from_static("resolution=merge-duplicates"),
        );

        // --- Payload with user_id ---
        let payload = json!({
            "user_id": user_id,
            "date": data_to_post.date,
            "total_span_minutes": data_to_post.total_span_minutes,
            "total_span": data_to_post.total_span,
            "first_boot": data_to_post.first_boot,
            "last_shutdown": data_to_post.last_shutdown,
        });

        println!("Attempting to post data to Supabase (Attempt {})...", retries + 1);

        // 3. Send Request
        let res = match client.post(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                // Handle network error (e.g., DNS failure, connection reset)
                eprintln!("Network Error: {}. Retrying...", e);
                retries += 1;
                if retries >= MAX_RETRIES {
                    return Err(anyhow!("Failed to post data after {} network retries: {}", MAX_RETRIES, e));
                }
                sleep(Duration::from_secs(2u64.pow(retries as u32))).await; // Exponential backoff
                continue;
            }
        };

        // 4. Process Response (Retry logic)
        match res.status() {
            s if s.is_success() => {
                println!("Successfully posted data. Status: {}", s);
                return Ok(());
            },

            StatusCode::UNAUTHORIZED => {
                eprintln!("API Error: Token unauthorized or expired (401). Attempting refresh.");
                retries = 0; // Reset retries after attempting auth resolution

                match refresh_access_token(admin_config, user_config).await {
                    Ok(_) => {
                        println!("Token refreshed successfully. Retrying data post...");
                        continue;
                    },
                    Err(e) => {
                        eprintln!("Automatic token refresh failed: {}. Attempting manual re-authentication.", e);
                        initial_setup_and_login(admin_config, user_config);

                        if user_config.access_token.is_some() {
                            println!("Manual re-authentication succeeded. Retrying...");
                            continue;
                        } else {
                            return Err(anyhow!("Failed to automatically refresh token and manual re-authentication also failed."));
                        }
                    }
                }
            },

            // Handle transient server errors (5xx)
            s if s.is_server_error() => {
                let body = res.text().await.unwrap_or_else(|_| String::from("No response body"));
                eprintln!("Server Error: Status {} - Response: {}. Retrying...", s, body);
                retries += 1;
                if retries >= MAX_RETRIES {
                    return Err(anyhow!("Failed to post data after {} server retries: Status {}", MAX_RETRIES, s));
                }
                sleep(Duration::from_secs(2u64.pow(retries as u32))).await; // Exponential backoff
                continue;
            }

            // Handle other client/permanent errors (4xx, excluding 401)
            s => {
                let body = res.text().await.unwrap_or_else(|_| String::from("No response body"));
                eprintln!("API Error: Status {} - Response: {}", s, body);
                if body.contains("policy") || body.contains("permission") {
                     eprintln!("HINT: This 4xx error (Status {}) strongly suggests a Row Level Security (RLS) policy issue on the '{}' table. Please ensure authenticated users have INSERT permission, and the `user_id` in the payload matches `auth.uid()`.", s, TABLE_NAME);
                }
                return Err(anyhow!("Supabase API failed with status {}: {}", s, body));
            }
        }
    }
}