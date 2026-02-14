use rand::{rngs::OsRng, RngCore};
use serde::Serialize;
use std::env;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use tauri::{Manager, State};

#[derive(Clone, Serialize)]
struct SessionConfig {
    base_url: String,
    token: String,
}

#[derive(Default)]
struct AppState {
    session: Mutex<Option<SessionConfig>>,
    child: Mutex<Option<Child>>,
}

fn generate_api_token() -> String {
    let mut bytes = [0_u8; 32];
    OsRng.fill_bytes(&mut bytes);
    bytes.iter().map(|byte| format!("{:02x}", byte)).collect()
}

fn backend_workdir() -> PathBuf {
    PathBuf::from("../backend")
}

fn spawn_backend(token: &str, port: u16) -> Result<Child, String> {
    let python_bin = env::var("IMEXPORT_BACKEND_PYTHON").unwrap_or_else(|_| "python3".to_string());

    let mut command = Command::new(python_bin);
    command
        .arg("-m")
        .arg("app.main")
        .current_dir(backend_workdir())
        .env("APP_API_TOKEN", token)
        .env("APP_BIND_HOST", "127.0.0.1")
        .env("APP_BIND_PORT", port.to_string())
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    if let Ok(path) = env::var("IMESSAGE_DB_PATH") {
        command.env("IMESSAGE_DB_PATH", path);
    }

    command
        .spawn()
        .map_err(|_| "Failed to launch backend process".to_string())
}

#[tauri::command]
fn session_config(state: State<'_, AppState>) -> Result<SessionConfig, String> {
    let guard = state
        .session
        .lock()
        .map_err(|_| "Session lock failed".to_string())?;
    guard
        .clone()
        .ok_or_else(|| "Session has not been initialized".to_string())
}

fn main() {
    tauri::Builder::default()
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![session_config])
        .setup(|app| {
            let token = generate_api_token();
            let port = 8765_u16;
            let base_url = format!("http://127.0.0.1:{port}");

            let child = spawn_backend(&token, port)?;
            let state: State<'_, AppState> = app.state();

            {
                let mut session_guard = state
                    .session
                    .lock()
                    .map_err(|_| "Session lock failed".to_string())?;
                *session_guard = Some(SessionConfig {
                    base_url,
                    token,
                });
            }

            {
                let mut child_guard = state
                    .child
                    .lock()
                    .map_err(|_| "Child lock failed".to_string())?;
                *child_guard = Some(child);
            }

            if let Some(window) = app.get_webview_window("main") {
                window.set_title("Messages Exporter")?;
            }

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while running tauri application")
        .run(|app_handle, event| {
            if let tauri::RunEvent::Exit = event {
                let state = app_handle.state::<AppState>();
                if let Ok(mut guard) = state.child.lock() {
                    if let Some(mut child) = guard.take() {
                        let _ = child.kill();
                    }
                }
            }
        });
}
