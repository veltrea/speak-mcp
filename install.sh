#!/bin/bash
# ==========================================
# speak-mcp Installer (English)
# ==========================================
set -e

INSTALL_DIR="$HOME/speak-mcp"
BINARY_NAME="speak-mcp"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

echo "======================================"
echo " speak-mcp Installer"
echo "======================================"
echo "Destination: $INSTALL_DIR"
echo ""

# ------------------------------------------
# 1. Build or copy pre-built binary
# ------------------------------------------
IS_RELEASE_ZIP=false

if [ -f "./$BINARY_NAME" ]; then
    echo "[INFO] Pre-built binary detected. Skipping build."
    IS_RELEASE_ZIP=true
else
    echo "[INFO] Source detected. Starting build..."

    if ! command -v cargo &> /dev/null; then
        echo "[ERROR] cargo not found."
        echo "  Please download the binary ZIP from the Releases page, or"
        echo "  install Rust and try again: https://rustup.rs"
        exit 1
    fi

    echo "[INFO] Building speak-mcp server..."
    cargo build --release

    echo "[INFO] Building speak-config tool..."
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
# 2. Copy files to install directory
# ------------------------------------------
mkdir -p "$INSTALL_DIR"

# speak-mcp binary
if [ "$IS_RELEASE_ZIP" = true ]; then
    cp "./$BINARY_NAME" "$INSTALL_DIR/"
elif [ -f "target/release/$BINARY_NAME" ]; then
    cp "target/release/$BINARY_NAME" "$INSTALL_DIR/"
else
    echo "[ERROR] speak-mcp binary not found."
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

# Setup scripts
if [ -d "./setup" ]; then
    cp -r "./setup" "$INSTALL_DIR/"
fi

# config.json (do not overwrite existing config)
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[INFO] Creating default config.json..."
    cat > "$INSTALL_DIR/config.json" <<EOF
{
  "voicevox_default_speaker": null,
  "aivis_default_speaker": null,
  "macos_default_voice": null
}
EOF
fi

echo ""
echo "[OK] Files installed to: $INSTALL_DIR"
echo ""

# ------------------------------------------
# 3. Auto-configure MCP clients
# ------------------------------------------
configure_json_file() {
    local config_file="$1"
    local label="$2"

    if [ ! -f "$config_file" ]; then
        mkdir -p "$(dirname "$config_file")"
        echo '{"mcpServers": {}}' > "$config_file"
    fi

    if grep -q '"speak"' "$config_file" 2>/dev/null; then
        echo "[SKIP] $label: 'speak' is already configured."
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
    echo "[OK] $label: Configuration updated."
}

ask_and_configure() {
    local config_file="$1"
    local label="$2"
    local extra_note="${3:-}"

    echo "--------------------------------------"
    echo "[$label] detected."
    echo "  Config file: $config_file"
    [ -n "$extra_note" ] && echo "  $extra_note"
    printf "  Auto-configure speak-mcp? [y/N]: "
    read -r answer
    case "$answer" in
        [yY]*)
            configure_json_file "$config_file" "$label"
            ;;
        *)
            echo "[SKIP] Skipped."
            ;;
    esac
    echo ""
}

echo "======================================"
echo " MCP Client Auto-Configuration"
echo "======================================"
echo ""

CONFIGURED_ANY=false

# --- Claude Desktop ---
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -d "$HOME/Library/Application Support/Claude" ] || [ -f "$CLAUDE_DESKTOP_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$CLAUDE_DESKTOP_CONFIG" "Claude Desktop" \
        "Please restart Claude Desktop after configuration."
fi

# --- Claude Code ---
CLAUDE_CODE_CONFIG="$HOME/.claude/settings.json"
if [ -d "$HOME/.claude" ] || [ -f "$CLAUDE_CODE_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$CLAUDE_CODE_CONFIG" "Claude Code" \
        "Also check your project's .mcp.json after configuration."
    echo "  [NOTE] Claude Code may also require the following in settings.json:"
    echo "    \"enabledMcpjsonServers\": [\"speak\"]"
    echo ""
fi

# --- Antigravity ---
ANTIGRAVITY_CONFIG="$HOME/Library/Application Support/Antigravity/config.json"
if [ -d "$HOME/Library/Application Support/Antigravity" ] || [ -f "$ANTIGRAVITY_CONFIG" ]; then
    CONFIGURED_ANY=true
    ask_and_configure "$ANTIGRAVITY_CONFIG" "Google Antigravity" \
        "Please restart Antigravity after configuration."
fi

# --- LM Studio ---
LMSTUDIO_MCP_DIR="$HOME/.lmstudio/extensions/plugins/mcp/speak"
LMSTUDIO_MCP_JSON="$LMSTUDIO_MCP_DIR/mcp.json"
if [ -d "$HOME/.lmstudio" ]; then
    CONFIGURED_ANY=true
    echo "--------------------------------------"
    echo "[LM Studio] detected."
    echo "  Install path: $LMSTUDIO_MCP_DIR"
    echo "  The binary will be copied and an mcp.json will be generated."
    printf "  Configure speak-mcp for LM Studio? [y/N]: "
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
            echo "[OK] LM Studio: Installed to $LMSTUDIO_MCP_DIR"
            echo "  Please restart LM Studio and enable the MCP plugin."
            ;;
        *)
            echo "[SKIP] Skipped."
            ;;
    esac
    echo ""
fi

# --- No clients detected ---
if [ "$CONFIGURED_ANY" = false ]; then
    echo "[INFO] No MCP clients detected."
    echo "  Please manually add the following to your client's config file:"
    echo ""
    echo '  "mcpServers": {'
    echo '    "speak": {'
    echo "      \"command\": \"$BINARY_PATH\""
    echo '    }'
    echo '  }'
    echo ""
fi

# ------------------------------------------
# 4. Done
# ------------------------------------------
echo "======================================"
echo " Installation complete!"
echo "======================================"
echo ""
echo "Binary : $BINARY_PATH"
echo "Config : $INSTALL_DIR/config.json"
if [ -d "$INSTALL_DIR/SpeakConfig.app" ]; then
    echo ""
    echo "To change the default voice, open SpeakConfig.app:"
    echo "  open \"$INSTALL_DIR/SpeakConfig.app\""
fi
echo ""
