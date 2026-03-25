#!/bin/bash
# ==========================================
# speak-mcp Build Script
# ==========================================
set -e

# scripts/ 内からでも Cargo ルート（speak-mcp-dev/）で動作させる
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "======================================"
echo " speak-mcp Build"
echo "======================================"
echo "Root: $REPO_ROOT"

# --- オプション解析 ---
PROFILE="release"
BUILD_CONFIG=true
PACKAGE_APP=true

for arg in "$@"; do
    case "$arg" in
        --debug)        PROFILE="debug" ;;
        --no-config)    BUILD_CONFIG=false ;;
        --no-package)   PACKAGE_APP=false ;;
        --help|-h)
            echo "Usage: scripts/build.sh [options]"
            echo ""
            echo "Options:"
            echo "  --debug       Build in debug mode (default: release)"
            echo "  --no-config   Skip building speak-config"
            echo "  --no-package  Skip packaging SpeakConfig.app"
            echo "  --help        Show this help"
            exit 0
            ;;
    esac
done

if ! command -v cargo &> /dev/null; then
    echo "[ERROR] cargo not found. Install Rust: https://rustup.rs"
    exit 1
fi

CARGO_FLAGS=""
[ "$PROFILE" = "release" ] && CARGO_FLAGS="--release"

# ------------------------------------------
# 1. speak-mcp サーバーのビルド
# ------------------------------------------
echo ""
echo "[1/2] Building speak-mcp server (profile: $PROFILE)..."
cargo build $CARGO_FLAGS

if [ "$PROFILE" = "release" ]; then
    BINARY="$REPO_ROOT/target/release/speak-mcp"
else
    BINARY="$REPO_ROOT/target/debug/speak-mcp"
fi

if [ ! -f "$BINARY" ]; then
    echo "[ERROR] Build failed: $BINARY not found."
    exit 1
fi

SIZE=$(du -sh "$BINARY" | cut -f1)
echo "[OK] speak-mcp built: $BINARY ($SIZE)"

# ------------------------------------------
# 2. speak-config ツールのビルド
# ------------------------------------------
if [ "$BUILD_CONFIG" = true ] && [ -d "$REPO_ROOT/speak-config" ]; then
    echo ""
    echo "[2/2] Building speak-config tool (profile: $PROFILE)..."
    cd "$REPO_ROOT/speak-config"
    cargo build $CARGO_FLAGS

    if [ "$PACKAGE_APP" = true ] && [ -f "package_app.sh" ]; then
        echo "[INFO] Packaging SpeakConfig.app..."
        bash package_app.sh
        if [ -d "SpeakConfig.app" ]; then
            echo "[OK] SpeakConfig.app created."
        fi
    fi
    cd "$REPO_ROOT"
else
    echo ""
    echo "[2/2] Skipping speak-config build."
fi

# ------------------------------------------
# 3. 完了サマリー
# ------------------------------------------
echo ""
echo "======================================"
echo " Build complete!"
echo "======================================"
echo ""
echo "Artifacts:"
[ -f "$REPO_ROOT/target/release/speak-mcp" ]       && echo "  $REPO_ROOT/target/release/speak-mcp"
[ -f "$REPO_ROOT/target/debug/speak-mcp" ]          && echo "  $REPO_ROOT/target/debug/speak-mcp"
[ -d "$REPO_ROOT/speak-config/SpeakConfig.app" ]    && echo "  $REPO_ROOT/speak-config/SpeakConfig.app"
echo ""
echo "To install, run:"
echo "  $REPO_ROOT/install.sh"
echo ""
