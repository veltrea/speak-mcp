#!/bin/bash
set -e

APP_NAME="SpeakConfig"
APP_DIR="${APP_NAME}.app"
BINARY_PATH="target/release/speak-config"
ICON_SOURCE="speak_config_icon.png" # This will be the generated image
ICON_SET_DIR="speak_config.iconset"

echo "📦 Packaging $APP_NAME.app..."

# 1. Ensure binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Binary not found at $BINARY_PATH. Run 'cargo build --release' in speak-config first."
    exit 1
fi

# 2. Create Directory Structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. Copy Binary
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# 4. Create Info.plist
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.veltrea.speak-config</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Create Icon (if source exists)
if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Creating AppIcon.icns..."
    mkdir -p "$ICON_SET_DIR"
    
    # Resize images for iconset
    sips -z 16 16     -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_16x16.png"
    sips -z 32 32     -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_16x16@2x.png"
    sips -z 32 32     -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_32x32.png"
    sips -z 64 64     -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_32x32@2x.png"
    sips -z 128 128   -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_128x128.png"
    sips -z 256 256   -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_128x128@2x.png"
    sips -z 256 256   -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_256x256.png"
    sips -z 512 512   -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_256x256@2x.png"
    sips -z 512 512   -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_512x512.png"
    sips -z 1024 1024 -s format png "$ICON_SOURCE" --out "$ICON_SET_DIR/icon_512x512@2x.png"

    # Convert iconset to icns
    iconutil -c icns "$ICON_SET_DIR"
    mv "speak_config.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    
    # Clean up
    rm -rf "$ICON_SET_DIR"
else
    echo "⚠️ Icon source '$ICON_SOURCE' not found. Using default icon."
fi

echo "✅ Created $APP_DIR"
