#!/bin/bash
set -e

# ==========================================
# speak-mcp Installer
# ==========================================

# インストール先ディレクトリ
# デフォルトはホームディレクトリ下の speak-mcp フォルダです。
# 必要に応じて変更してください。
INSTALL_DIR="$HOME/speak-mcp"

echo "📢 Installing speak-mcp..."
echo "📂 Destination: $INSTALL_DIR"

# 1. 動作モードの判定とビルド (必要な場合)
IS_RELEASE_ZIP=false

if [ -f "./speak-mcp" ]; then
    echo "📦 Pre-built binaries detected. Skipping build..."
    IS_RELEASE_ZIP=true
else
    # バイナリが無い場合はビルドを試みる
    echo "🔨 Source detected. Starting build process..."

    if ! command -v cargo &> /dev/null; then
        echo "❌ Error: 実行に必要なファイルが見つかりません。"
        echo "   Google Antigravity でこのプロジェクトを開き、AIに「ビルドを実行して」と依頼するか、"
        echo "   Releases ページから最新の ZIP ファイル (バイナリ入り) をダウンロードしてください。"
        exit 1
    fi

    echo "   Building speak-mcp server..."
    cargo build --release

    echo "   Building speak-config tool..."
    if [ -d "speak-config" ]; then
        cd speak-config
        cargo build --release
        # 簡易的に .app 化スクリプトがあれば実行、なければバイナリのみ
        if [ -f "package_app.sh" ]; then
             ./package_app.sh
        fi
        cd ..
    fi
fi

# 2. インストールディレクトリの準備
mkdir -p "$INSTALL_DIR"

# 3. ファイルの配置
echo "� Copying files to $INSTALL_DIR..."

# --- speak-mcp (Server) ---
if [ "$IS_RELEASE_ZIP" = true ]; then
    cp "./speak-mcp" "$INSTALL_DIR/"
elif [ -f "target/release/speak-mcp" ]; then
    cp "target/release/speak-mcp" "$INSTALL_DIR/"
else
    echo "❌ Error: speak-mcp binary not found."
    exit 1
fi

# --- SpeakConfig (App or Binary) ---
# アプリバンドル (.app) があればそれをコピー (優先)
if [ -d "./SpeakConfig.app" ]; then
    # ZIP版
    echo "   Copying SpeakConfig.app..."
    rm -rf "$INSTALL_DIR/SpeakConfig.app"
    cp -r "./SpeakConfig.app" "$INSTALL_DIR/"
    # 実行権限の念押し
    chmod +x "$INSTALL_DIR/SpeakConfig.app/Contents/MacOS/SpeakConfig"
elif [ -d "speak-config/SpeakConfig.app" ]; then
    # ビルド直後
    echo "   Copying SpeakConfig.app..."
    rm -rf "$INSTALL_DIR/SpeakConfig.app"
    cp -r "speak-config/SpeakConfig.app" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/SpeakConfig.app/Contents/MacOS/SpeakConfig"
elif [ -f "speak-config/target/release/speak-config" ]; then
    # .app化に失敗した場合はバイナリだけコピー
    echo "   Copying speak-config binary (App bundle not found)..."
    cp "speak-config/target/release/speak-config" "$INSTALL_DIR/"
fi

# --- Scripts ---
if [ -d "./setup" ]; then
    cp -r "./setup" "$INSTALL_DIR/"
fi

# config.json (既存の設定があれば上書きしない)
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "📄 Creating default config.json..."
    echo '{
  "voicevox_default_speaker": null,
  "aivis_default_speaker": null,
  "macos_default_voice": null
}' > "$INSTALL_DIR/config.json"
fi

echo "✅ Installation complete!"
echo ""
echo "=========================================="
echo "🎉 Next Steps"
echo "=========================================="
echo "Google Antigravity の設定に以下を追加してください:"
echo ""
echo "Executable Path: $INSTALL_DIR/speak-mcp"
echo ""
echo "--- Config JSON ---"
echo "{"
echo "  \"mcpServers\": {"
echo "    \"speak\": {"
echo "      \"command\": \"$INSTALL_DIR/speak-mcp\""
echo "    }"
echo "  }"
echo "}"
echo "-------------------"
echo ""
echo "設定後、Antigravityを再起動してください。"
echo "デフォルトの声設定は、以下のアプリから変更できます:"
echo "open $INSTALL_DIR/SpeakConfig.app"
echo ""
echo "または、Finderで $INSTALL_DIR を開き、『SpeakConfig』を起動してください。"
