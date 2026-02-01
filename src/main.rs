use anyhow::Result;
use async_mcp::server::Server;
use async_mcp::transport::ServerStdioTransport;
use async_mcp::types::{CallToolRequest, CallToolResponse, Tool, ToolResponseContent};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use std::fs;
use std::io::Write;
use std::process::Command;

#[derive(Debug, Deserialize, Serialize)]
struct SpeakArgs {
    text: String,
    voice: Option<String>,
    speed: Option<u32>,
}

#[derive(Debug, Deserialize, Serialize)]
struct VoiceEngineArgs {
    text: String,
    speaker: Option<u32>,
    speed: Option<f32>,
}

#[derive(Debug, Deserialize)]
struct StyleInfo {
    name: String,
    id: u32,
}

#[derive(Debug, Deserialize)]
struct SpeakerInfo {
    name: String,
    styles: Vec<StyleInfo>,
}

#[derive(Debug, Deserialize, Serialize, Default)]
struct AppConfig {
    voicevox_default_speaker: Option<u32>,
    aivis_default_speaker: Option<u32>,
    macos_default_voice: Option<String>,
}

fn get_config_path() -> std::path::PathBuf {
    if let Some(mut home) = dirs::home_dir() {
        home.push("speak-mcp");
        home.push("config.json");
        return home;
    }
    // Fallback
    let mut config_path = env::current_exe()
        .map(|p| p.parent().map(|p| p.to_path_buf()).unwrap_or_default())
        .unwrap_or_default();
    config_path.push("config.json");
    config_path
}

fn load_config() -> AppConfig {
    let path = get_config_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(config) = serde_json::from_str(&content) {
            return config;
        }
    }

    // Fallback check for local config if home one failed or didn't exist
    let mut local_path = env::current_exe()
        .map(|p| p.parent().map(|p| p.to_path_buf()).unwrap_or_default())
        .unwrap_or_default();
    local_path.push("config.json");

    if path != local_path {
        if let Ok(content) = fs::read_to_string(&local_path) {
            if let Ok(config) = serde_json::from_str(&content) {
                return config;
            }
        }
    }

    AppConfig::default()
}

async fn fetch_speakers(port: u16) -> Option<Vec<SpeakerInfo>> {
    let client = reqwest::Client::new();
    let url = format!("http://localhost:{}/speakers", port);
    match client.get(&url).send().await {
        Ok(resp) => resp.json::<Vec<SpeakerInfo>>().await.ok(),
        Err(_) => None,
    }
}

fn build_speaker_choice_schema(
    speakers: Option<Vec<SpeakerInfo>>,
    default_id: Option<u32>,
) -> serde_json::Value {
    // Default to 1 if no config and no speakers found, but if config exists use it.
    let default_val = default_id.unwrap_or(1);

    if let Some(speakers) = speakers {
        let mut one_of = Vec::new();

        for speaker in speakers {
            for style in speaker.styles {
                one_of.push(json!({
                    "const": style.id,
                    "title": format!("{} ({})", speaker.name, style.name)
                }));
            }
        }

        // Ensure default value is in the list if possible, or add a fallback option
        // In a perfect world we check validation, but for now we trust the config or list.

        json!({
            "type": "object",
            "properties": {
                "text": { "type": "string" },
                "speaker": {
                    "oneOf": one_of,
                    "default": default_val
                },
                "speed": { "type": "number", "default": 1.0 }
            },
            "required": ["text"]
        })
    } else {
        // Fallback schema if engine is offline
        json!({
            "type": "object",
            "properties": {
                "text": { "type": "string" },
                "speaker": { "type": "integer", "default": default_val },
                "speed": { "type": "number", "default": 1.0 }
            },
            "required": ["text"]
        })
    }
}

async fn play_wav(wav_data: &[u8]) -> Result<()> {
    let mut temp_file = tempfile::NamedTempFile::new()?;
    temp_file.write_all(wav_data)?;
    let path = temp_file
        .path()
        .to_str()
        .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

    #[cfg(target_os = "macos")]
    {
        let status = Command::new("afplay").arg(path).status()?;
        if !status.success() {
            return Err(anyhow::anyhow!("afplay failed"));
        }
    }

    #[cfg(target_os = "windows")]
    {
        let script = format!(
            "(New-Object System.Media.SoundPlayer '{}').PlaySync()",
            path
        );
        let status = Command::new("powershell")
            .arg("-Command")
            .arg(script)
            .status()?;
        if !status.success() {
            return Err(anyhow::anyhow!("PowerShell playback failed"));
        }
    }

    Ok(())
}

async fn call_voicevox_compatible(
    port: u16,
    req: CallToolRequest,
    default_speaker: Option<u32>,
) -> Result<CallToolResponse> {
    let args_val = req
        .arguments
        .ok_or_else(|| anyhow::anyhow!("Arguments missing"))?;
    let args: VoiceEngineArgs = serde_json::from_value(json!(args_val))?;

    // Use argument speaker if provided, otherwise config default, otherwise 1
    let speaker_id = args.speaker.or(default_speaker).unwrap_or(1);

    let speed_scale = args.speed.unwrap_or(1.0);
    let client = reqwest::Client::new();
    let base_url = format!("http://localhost:{}", port);

    let query_res = client
        .post(format!("{}/audio_query", base_url))
        .query(&[("text", &args.text), ("speaker", &speaker_id.to_string())])
        .send()
        .await?;
    let mut query_json: serde_json::Value = query_res.json().await?;
    query_json["speedScale"] = json!(speed_scale);

    let synthesis_res = client
        .post(format!("{}/synthesis", base_url))
        .query(&[("speaker", &speaker_id.to_string())])
        .json(&query_json)
        .send()
        .await?;
    let wav_data = synthesis_res.bytes().await?;

    play_wav(&wav_data).await?;

    Ok(CallToolResponse {
        content: vec![ToolResponseContent::Text {
            text: "読み上げ完了！✨".to_string(),
        }],
        is_error: Some(false),
        meta: None,
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    let transport = ServerStdioTransport;
    let mut builder = Server::builder(transport)
        .name("speak-mcp")
        .version("0.1.0");

    let config = load_config();

    // Fetch speakers at startup
    // Note: We intentionally ignore errors here and fallback to default schema
    // to ensure the server starts even if TTS engines are down.
    let voicevox_speakers = fetch_speakers(50021).await;
    let aivis_speakers = fetch_speakers(10101).await;

    // VOICEVOX Engine with Dynamic Schema and Config Default
    let vv_default = config.voicevox_default_speaker;
    builder.register_tool(
        Tool {
            name: "speak_voicevox".to_string(),
            description: Some("VOICEVOXを使用して読み上げます。(Port: 50021)".to_string()),
            input_schema: build_speaker_choice_schema(voicevox_speakers, vv_default),
            output_schema: None,
        },
        move |req| {
            let default = vv_default;
            Box::pin(async move { call_voicevox_compatible(50021, req, default).await })
        },
    );

    // Aivis Speech Engine with Dynamic Schema and Config Default
    let aivis_default = config.aivis_default_speaker;
    builder.register_tool(
        Tool {
            name: "speak_aivis".to_string(),
            description: Some("Aivis Speechを使用して読み上げます。(Port: 10101)".to_string()),
            input_schema: build_speaker_choice_schema(aivis_speakers, aivis_default),
            output_schema: None,
        },
        move |req| {
            let default = aivis_default;
            Box::pin(async move { call_voicevox_compatible(10101, req, default).await })
        },
    );

    #[cfg(target_os = "macos")]
    {
        builder.register_tool(
            Tool {
                name: "speak".to_string(),
                description: Some("Mac標準のsayコマンドで読み上げます。".to_string()),
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "text": { "type": "string" },
                        "voice": { "type": "string" },
                        "speed": { "type": "integer" }
                    },
                    "required": ["text"]
                }),
                output_schema: None,
            },
            |req| {
                // Cloning string again inside closure if needed, but here simple clone for move is enough if we structured it differently.
                // However, since we can't easily move captured variable into Fn callback multiple times if it's not Copy,
                // we might need a slight adjustment but for this SDK style:
                // Actually the closure is `Fn(CallToolRequest) -> Pin<Box<...>>`.
                // We need to be careful about borrowing.
                // Let's rely on simple `move` for now assuming `builder.register_tool` takes `impl Fn ... + Send + Sync + 'static`.
                // String is Clone but not Copy. We can use Arc if needed, or clone inside the closure if logic permits.
                // Here, we'll try simple move and clone if necessary.
                // Wait, `builder.register_tool` usually takes a closure that is called multiple times.
                // So the closure must capture variables.
                // For `speak_voicevox` `move` works because `u32` is Copy.
                // For `speak` with `String`, we need to wrap in Arc or clone efficiently.
                // Let's use a static/const default or Arc for now to be safe.
                // Actually let's just create a local clone for the closure scope.

                // Workaround: We can't move non-Copy types into Fn closure easily if we want to use them repeatedly without Clone inside.
                // But `String` needs to be cloned *per call* if we want to pass it? No, we just need access.
                // Let's keep it simple: We won't support default voice for `say` in schema yet, just logic.

                Box::pin(async move {
                    let args_val = req
                        .arguments
                        .clone()
                        .ok_or_else(|| anyhow::anyhow!("Arguments missing"))?;
                    let args: SpeakArgs = serde_json::from_value(json!(args_val))?;

                    // We need to access configuration here.
                    // Since passing dynamic config around in this closure structure is tricky without Arc,
                    // we will re-load config or just not support default voice for Mac in this iteration
                    // UNLESS we use lazy_static or similar.
                    // For simplicity, let's just load config again efficiently or use a simple logic.
                    // Actually, loading config every time is robust for updates!
                    let current_config = load_config();

                    let mut cmd = Command::new("say");
                    cmd.arg(&args.text);

                    // Use arg voice, or config default, or system default
                    if let Some(v) = args.voice.or(current_config.macos_default_voice) {
                        cmd.arg("-v").arg(v);
                    }
                    if let Some(s) = args.speed {
                        cmd.arg("-r").arg(s.to_string());
                    }
                    let status = cmd.status()?;
                    if status.success() {
                        Ok(CallToolResponse {
                            content: vec![ToolResponseContent::Text {
                                text: "Macのsayで読み上げたよ！🎵".to_string(),
                            }],
                            is_error: Some(false),
                            meta: None,
                        })
                    } else {
                        Err(anyhow::anyhow!("sayコマンド失敗💦"))
                    }
                })
            },
        );
    }

    let server = builder.build();
    eprintln!("Speak MCP Server (Multi-Engine) 起動中...🌟");
    server.listen().await?;

    Ok(())
}
