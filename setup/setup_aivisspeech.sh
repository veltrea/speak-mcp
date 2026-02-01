#!/bin/bash
set -e

# AivisSpeech 最新版のdmg (Apple Silicon用) のURLを取得
# 注: 1.1.0以降が推奨されているが、現在の最新タグが1.0.0の場合はそれを取得
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/Aivis-Project/AivisSpeech/releases/latest | grep "browser_download_url" | grep "arm64" | grep ".dmg" | cut -d "\"" -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Download URL not found...💦"
    exit 1
fi

DMG_FILE="AivisSpeech.dmg"
echo "Downloading AivisSpeech from: $DOWNLOAD_URL"
curl -L -o "$DMG_FILE" "$DOWNLOAD_URL"

echo "Mounting DMG..."
hdiutil detach /Volumes/AivisSpeech* 2>/dev/null || true
MOUNT_PATH=$(hdiutil attach "$DMG_FILE" -nobrowse | grep "/Volumes/AivisSpeech" | awk -F"	" "{print \$NF}")

echo "Mounted at: $MOUNT_PATH"

echo "Installing to /Applications..."
if [ -d "/Applications/AivisSpeech.app" ]; then
    echo "Existing AivisSpeech.app found, removing..."
    rm -rf "/Applications/AivisSpeech.app"
fi
cp -R "$MOUNT_PATH/AivisSpeech.app" /Applications/

echo "Unmounting DMG..."
hdiutil detach "$MOUNT_PATH"

echo "Removing quarantine flag..."
xattr -d com.apple.quarantine /Applications/AivisSpeech.app || true

echo "AivisSpeech has been installed successfully! 🌟"
echo "AivisSpeechを一度手動で起動して、エンジンが localhost:10101 で待機していることを確認してね！"

