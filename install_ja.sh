#!/bin/bash
# ==========================================
# speak-mcp インストールスクリプト（日本語版）
# ==========================================
set -e

INSTALL_DIR="$HOME/speak-mcp"
BINARY_NAME="speak-mcp"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

echo "======================================"
echo " speak-mcp インストーラー"
echo "======================================"
echo "インストール先: $INSTALL_DIR"
echo ""

# ------------------------------------------
# 1. ビルドまたはバイナリのコピー
# ------------------------------------------
IS_RELEASE_ZIP=false

if [ -f "./$BINARY_NAME" ]; then
    echo "[INFO] プリビルドバイナリを検出しました。ビルドをスキップします。"
    IS_RELEASE_ZIP=true
else
    echo "[INFO] ソースコードを検出しました。ビルドを開始します..."

    if ! command -v cargo &> /dev/null; then
        echo "[ERROR] cargo が見つかりません。"
        echo "  Releases ページからバイナリ入り ZIP をダウンロードするか、"
        echo "  Rust をインストールしてから再実行してください。"
        echo "  https://rustup.rs"
        exit 1
    fi

    echo "[INFO] speak-mcp サーバーをビルド中..."
    cargo build --release

    echo "[INFO] speak-config ツールをビルド中..."
    if [ -d "speak-config" ]; then
        cd speak-config
        cargo build --release
        if [ -f "package_app.sh" ]; then
            ./package_app.sh
        fi
        cd ..
    fi
fi

# ------------------------------------------
# 2. インストールディレクトリへの配置
# ------------------------------------------
mkdir -p "$INSTALL_DIR"

# speak-mcp バイナリ
if [ "$IS_RELEASE_ZIP" = true ]; then
    cp "./$BINARY_NAME" "$INSTALL_DIR/"
elif [ -f "target/release/$BINARY_NAME" ]; then
    cp "target/release/$BINARY_NAME" "$INSTALL_DIR/"
else
    echo "[ERROR] speak-mcp バイナリが見つかりません。"
    exit 1
fi
chmod +x "$BINARY_PATH"

# SpeakConfig.app
if [ -d "./SpeakConfig.app" ]; then
    rm -rf "$INSTALL_DIR/SpeakConfig.app"
    cp -r "./SpeakConfig.app" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/SpeakConfig.app/Contents/MacOS/SpeakConfig"
elif [ -d "speak-config/SpeakConfig.app" ]; then
    rm -rf "$INSTALL_DIR/SpeakConfig.app"
    cp -r "speak-config/SpeakConfig.app" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/SpeakConfig.app/Contents/MacOS/SpeakConfig"
elif [ -f "speak-config/target/release/speak-config" ]; then
    cp "speak-config/target/release/speak-config" "$INSTALL_DIR/"
fi

# setup スクリプト
if [ -d "./setup" ]; then
    cp -r "./setup" "$INSTALL_DIR/"
fi

# config.json（既存設定は上書きしない）
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[INFO] デフォルトの config.json を作成中..."
    cat > "$INSTALL_DIR/config.json" <<EOF
{
  "voicevox_default_speaker": null,
  "aivis_default_speaker": null,
  "macos_default_voice": null
}
EOF
fi

echo ""
echo "[OK] ファイルをインストールしました: $INSTALL_DIR"
echo ""

# ------------------------------------------
# 3. MCP クライアントへの自動設定
# ------------------------------------------
configure_json_file() {
    local config_file="$1"
    local label="$2"

    if [ ! -f "$config_file" ]; then
        mkdir -p "$(dirname "$config_file")"
        echo '{"mcpServers": {}}' > "$config_file"
    fi

    if grep -q '"speak"' "$config_file" 2>/dev/null; then
        echo "[SKIP] $label: speak は既に設定済みです。"
        return
    fi

    python3 - "$config_file" "$BINARY_PATH" <<'PYEOF'
import json, sys
path, binary = sys.argv[1], sys.argv[2]
with open(path, 'r') as f:
    data = json.load(f)
data.setdefault('mcpServers', {})
data['mcpServers']['speak'] = {'command': binary}
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
    echo "[OK] $label: 設定を追記しました。"
}

ask_and_configure() {
    local config_file="$1"
    local label="$2"
    local extra_note="${3:-}"

    echo "--------------------------------------"
    echo "[$label] が検出されました。"
    echo "  設定ファイル: $config_file"
    [ -n "$extra_note" ] && echo "  $extra_note"
    printf "  speak-mcp を自動設定しますか? [y/N]: "
    read -r answer
    case "$answer" in
        [yY]*)
            configure_json_file "$config_file" "$label"
            ;;
        *)
            echo "[SKIP] スキップしました。"
            ;;
    esac
    echo ""
}

echo "======================================"
echo " MCP クライアント自動設定"
echo "======================================"
echo ""

CONFIGURED_ANY=false

# --- Claude Desktop ---
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -d "$HOME/Library/Application Support/Claude" ] || [ -f "$CLAUDE_DESKTOP_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$CLAUDE_DESKTOP_CONFIG" "Claude Desktop" \
        "設定後、Claude Desktop を再起動してください。"
fi

# --- Claude Code ---
CLAUDE_CODE_CONFIG="$HOME/.claude/settings.json"
if [ -d "$HOME/.claude" ] || [ -f "$CLAUDE_CODE_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$CLAUDE_CODE_CONFIG" "Claude Code" \
        "設定後、プロジェクトの .mcp.json も確認してください。"
    echo "  [NOTE] Claude Code では以下の設定も必要な場合があります:"
    echo "  $CLAUDE_CODE_CONFIG の enabledMcpjsonServers に \"speak\" を追加:"
    echo "    \"enabledMcpjsonServers\": [\"speak\"]"
    echo ""
fi

# --- Antigravity ---
ANTIGRAVITY_CONFIG="$HOME/Library/Application Support/Antigravity/config.json"
if [ -d "$HOME/Library/Application Support/Antigravity" ] || [ -f "$ANTIGRAVITY_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$ANTIGRAVITY_CONFIG" "Google Antigravity" \
        "設定後、Antigravity を再起動してください。"
fi

# --- LM Studio ---
# LM Studio は ~/.lmstudio/extensions/plugins/mcp/<name>/ に配置する
LMSTUDIO_MCP_DIR="$HOME/.lmstudio/extensions/plugins/mcp/speak"
LMSTUDIO_MCP_JSON="$HOME/.lmstudio/extensions/plugins/mcp/speak/mcp.json"
if [ -d "$HOME/.lmstudio" ]; then
    CONFIGURED_ANY=true
    echo "--------------------------------------"
    echo "[LM Studio] が検出されました。"
    echo "  配置先: $LMSTUDIO_MCP_DIR"
    echo "  バイナリを専用ディレクトリにコピーして mcp.json を生成します。"
    printf "  speak-mcp を LM Studio に設定しますか? [y/N]: "
    read -r answer
    case "$answer" in
        [yY]*)
            mkdir -p "$LMSTUDIO_MCP_DIR"
            cp "$BINARY_PATH" "$LMSTUDIO_MCP_DIR/"
            chmod +x "$LMSTUDIO_MCP_DIR/$BINARY_NAME"
            cat > "$LMSTUDIO_MCP_JSON" <<EOF
{
  "name": "speak",
  "version": "0.1.0",
  "description": "Text-to-speech MCP server (VOICEVOX / Aivis Speech / macOS say)",
  "command": "$LMSTUDIO_MCP_DIR/$BINARY_NAME"
}
EOF
            echo "[OK] LM Studio: $LMSTUDIO_MCP_DIR に配置しました。"
            echo "  LM Studio を再起動して MCP プラグインを有効化してください。"
            ;;
        *)
            echo "[SKIP] スキップしました。"
            ;;
    esac
    echo ""
fi

# --- どのクライアントも検出されなかった場合 ---
if [ "$CONFIGURED_ANY" = false ]; then
    echo "[INFO] MCP クライアントが検出されませんでした。"
    echo "  以下の設定を各クライアントの設定ファイルに手動で追加してください:"
    echo ""
    echo '  "mcpServers": {'
    echo '    "speak": {'
    echo "      \"command\": \"$BINARY_PATH\""
    echo '    }'
    echo '  }'
    echo ""
fi

# ------------------------------------------
# 4. 完了メッセージ
# ------------------------------------------
echo "======================================"
echo " インストール完了!"
echo "======================================"
echo ""
echo "バイナリ : $BINARY_PATH"
echo "設定ファイル: $INSTALL_DIR/config.json"
if [ -d "$INSTALL_DIR/SpeakConfig.app" ]; then
    echo ""
    echo "デフォルト音声の設定は SpeakConfig.app から変更できます:"
    echo "  open \"$INSTALL_DIR/SpeakConfig.app\""
fi
echo ""
