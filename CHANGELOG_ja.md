# 変更履歴 (Changelog)

このファイルには、`speak-mcp` プロジェクトの重要な変更履歴が記録されています。

## [v1.1.1] - 2026-03-30

### 修正 (Fixed)

- `src/main.rs`: TTSエンジン未起動時に無限待機でEOFフリーズが発生する定常的なバグを解決するため、`reqwest` HTTP通信にタイムアウト（500ms / 30s）を追加しました。

## [v1.1.0] - 2026-03-25

### 修正 (Fixed)

- `Cargo.toml`: `edition = "2024"` → `"2021"` に変更（stable Rust でのビルド不可を修正）
- `Cargo.toml`: `async-mcp = "0.1"` → `"=0.1.3"` にバージョン固定
- `src/main.rs`: 起動メッセージの絵文字を除去（一部MCP クライアントとの互換性向上）

### 追加 (Added)

- `install.sh`: Claude Desktop / Claude Code / Google Antigravity / LM Studio を自動検出し設定するマルチクライアント対応インストーラーに刷新
- `install_ja.sh`: 上記の日本語ローカライズ版を追加
- `scripts/build.sh`: ビルド専用スクリプトを追加（`--debug` / `--no-config` / `--no-package` オプション付き）
- `README_ja.md`: 日本語版 README を追加（英語版 README.md がデフォルトに変更）
- `docs/HowTo.md`: 英語版 How To を追加（日本語版は `docs/HowTo_ja.md` に移動）

### 変更 (Changed)

- リポジトリ構造を整理: ソースコードを `speak-mcp-dev/` サブディレクトリに移動
- `docs/HowTo.md` を `docs/` ディレクトリに移動
- `README.md` を英語版（デフォルト）に変更

---

## [v1.0.1] - 2026-02-19


### 修正 (Fixed)

#### MCPツールが読み込まれない問題の修正

**問題:**
- CursorなどのMCPクライアントで `speak-mcp` サーバーが認識されるが、ツールが読み込まれない状態（"No tools, prompts, or resources"）が発生していた
- `async-mcp` の正しいAPIを使用していなかった

**原因:**
- `Server::builder().register_tool()` という存在しないメソッドを使用していた
- `async-mcp` v0.1.3 では、`request_handler` を使って `"tools/list"` と `"tools/call"` を手動で処理する必要がある

**修正内容:**

1. **APIの変更**
   - `register_tool()` メソッドを削除
   - `request_handler("tools/list", ...)` と `request_handler("tools/call", ...)` を使用するように変更

2. **型定義の追加**
   - `async_mcp::types` から `ListRequest`, `ServerCapabilities`, `ToolsListResponse` をインポート
   - `std::sync::Arc` を追加してツールリストとコンフィグを共有

3. **データ構造の修正**
   - `SpeakerInfo` と `StyleInfo` 構造体に `Clone` トレイトを追加
   - ツールリストを `Arc` で共有するように変更

4. **リクエストハンドラーの実装**
   - `tools/list`: 登録されているツールのリストを返すハンドラーを実装
   - `tools/call`: ツール名に応じて適切な関数を呼び出すハンドラーを実装
     - `speak_voicevox`: VOICEVOXエンジンを使用
     - `speak_aivis`: Aivis Speechエンジンを使用
     - `speak` (macOSのみ): macOS標準の `say` コマンドを使用

5. **引数の処理方法の修正**
   - `CallToolRequest` の `arguments` が `HashMap<String, serde_json::Value>` であることを考慮
   - `serde_json::to_value()` を使って `HashMap` を `Value` に変換

6. **サーバー機能の宣言**
   - `ServerCapabilities` でツールサポートを明示的に宣言

**技術的詳細:**

```rust
// 修正前（動作しない）
builder.register_tool(
    Tool { ... },
    |req| { ... }
);

// 修正後（正しい実装）
let tools_arc = Arc::new(tools);
builder
    .capabilities(ServerCapabilities {
        tools: Some(json!({})),
        ..Default::default()
    })
    .request_handler("tools/list", {
        let tools = tools_arc.clone();
        move |_req: ListRequest| {
            Box::pin(async move {
                Ok(ToolsListResponse {
                    tools: tools.as_ref().clone(),
                    next_cursor: None,
                    meta: None,
                })
            })
        }
    })
    .request_handler("tools/call", {
        let config = config_arc.clone();
        move |req: CallToolRequest| {
            Box::pin(async move {
                match req.name.as_str() {
                    "speak_voicevox" => { ... }
                    "speak_aivis" => { ... }
                    "speak" => { ... }
                    _ => Err(...)
                }
            })
        }
    });
```

**影響範囲:**
- `src/main.rs`: メインのサーバー実装を全面的に書き換え
- 既存の機能（VOICEVOX、Aivis Speech、macOS say）はすべて維持
- 外部APIの変更なし（ツール名、引数、戻り値は同じ）

**検証:**
- `cargo check`: コンパイルエラーなし
- `cargo build --release`: リリースビルド成功

**次のステップ:**
- Cursorを再起動して、MCPサーバーがツールを正しく認識することを確認
- 各ツール（`speak_voicevox`, `speak_aivis`, `speak`）の動作確認

---

## [v1.0.0] - 2026-02-01

### 追加 (Added)

- 初回リリース
- VOICEVOXエンジンサポート（Port: 50021）
- Aivis Speechエンジンサポート（Port: 10101）
- macOS標準 `say` コマンドサポート
- 設定ファイル (`config.json`) によるデフォルト話者設定
- `speak-config` GUIツールによる設定管理
