#!/bin/bash
set -e

# VOICEVOX 最新版のdmg (Apple Silicon用) のURLを取得
# GitHub APIから最新リリースの資産リストを取得し、macOS用かつarm64用のdmgを探します。
# 命名規則の変動に備えて、複数のキーワードで絞り込みます。
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/VOICEVOX/voicevox/releases/latest | grep "browser_download_url" | grep "dmg" | grep "macos" | grep "arm64" | cut -d "\"" -f 4)

# もしarm64だけで見つからない場合（命名規則が変わった場合など）、"cpu"版などの可能性も考慮して少し緩めるか、
# ユーザーに手動ダウンロードを促す。いったんシンプルなgrepチェーンで試行。

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Download URL not found...💦"
    echo "VOICEVOXのリリースページの命名規則が変わった可能性があります。"
    echo "手動でのダウンロードをお願いします: https://voicevox.hiroshiba.jp/"
    exit 1
fi

DMG_FILE="VOICEVOX.dmg"
echo "Downloading VOICEVOX from: $DOWNLOAD_URL"
curl -L -o "$DMG_FILE" "$DOWNLOAD_URL"

echo "Mounting DMG..."
hdiutil detach /Volumes/VOICEVOX* 2>/dev/null || true
MOUNT_PATH=$(hdiutil attach "$DMG_FILE" -nobrowse | grep "/Volumes/VOICEVOX" | awk -F"	" "{print \$NF}")

if [ -z "$MOUNT_PATH" ]; then
    echo "Failed to mount DMG."
    exit 1
fi

echo "Mounted at: $MOUNT_PATH"

echo "Installing to /Applications..."
if [ -d "/Applications/VOICEVOX.app" ]; then
    echo "Existing VOICEVOX.app found, removing..."
    rm -rf "/Applications/VOICEVOX.app"
fi

# DMGの中身がどうなっているか確認が必要だが、通常は VOICEVOX.app が直下にあるか、
# .appファイルをコピーすれば良い。
# 名前が "VOICEVOX.app" であると仮定。
if [ -d "$MOUNT_PATH/VOICEVOX.app" ]; then
    cp -R "$MOUNT_PATH/VOICEVOX.app" /Applications/
else
    # もし直下にない場合、最初に見つかった .app をコピーするロジック（Aivisと同じ）
    APP_PATH=$(find "$MOUNT_PATH" -maxdepth 1 -name "*.app" | head -n 1)
    if [ -n "$APP_PATH" ]; then
        echo "Found app at $APP_PATH"
        cp -R "$APP_PATH" /Applications/
    else
        echo "VOICEVOX.app not found in DMG."
        hdiutil detach "$MOUNT_PATH"
        exit 1
    fi
fi

echo "Unmounting DMG..."
hdiutil detach "$MOUNT_PATH"

echo "Removing quarantine flag..."
xattr -d com.apple.quarantine /Applications/VOICEVOX.app || true

echo "VOICEVOX has been installed successfully! 💚"
echo "VOICEVOXを一度手動で起動して、エンジンが有効になっていることを確認してね！"
