# Changelog

> 🇯🇵 [日本語版はこちら](CHANGELOG_ja.md)

All notable changes to `speak-mcp` are documented here.

## [Unreleased] - 2026-03-25

### Fixed

- `Cargo.toml`: Changed `edition = "2024"` to `"2021"` (fixes build failure on stable Rust)
- `Cargo.toml`: Pinned `async-mcp` to `=0.1.3` for reproducible builds
- `src/main.rs`: Removed emoji from startup message for better MCP client compatibility
- `install.sh` / `install_ja.sh`: Fixed Claude Code configuration — was incorrectly adding `mcpServers` to `settings.json` (which rejects unknown fields). Now correctly writes to `~/.claude/.mcp.json` and adds `enabledMcpjsonServers` to `settings.json`
- `install.sh` / `install_ja.sh`: When `settings.json` doesn't exist, now creates it with `enabledMcpjsonServers` instead of just printing a warning

### Added

- `install.sh`: Rewritten as a multi-client installer with auto-detection for Claude Desktop, Claude Code, Google Antigravity, and LM Studio
- `install_ja.sh`: Japanese localized version of the installer
- `scripts/build.sh`: Standalone build script with `--debug`, `--no-config`, `--no-package` options
- `README_ja.md`: Japanese README (English `README.md` is now the default)
- `docs/HowTo.md`: English How To guide; Japanese version moved to `docs/HowTo_ja.md`
- `CHANGELOG_ja.md`: Japanese changelog (this file is now the English default)

### Changed

- Reorganized repository: source code moved into `speak-mcp-dev/` subdirectory
- `docs/HowTo.md` moved into `docs/` directory
- `README.md` changed to English as the default

---

## [Unreleased] - 2026-02-19

### Fixed

#### MCP tools not loading

**Problem:** MCP clients like Cursor recognized the server but showed "No tools, prompts, or resources".

**Cause:** Used a non-existent `register_tool()` method. `async-mcp` v0.1.3 requires manual `request_handler` registration for `tools/list` and `tools/call`.

**Fix:**

1. Replaced `register_tool()` with `request_handler("tools/list", ...)` and `request_handler("tools/call", ...)`
2. Added `ListRequest`, `ServerCapabilities`, `ToolsListResponse` from `async_mcp::types`
3. Added `Clone` trait to `SpeakerInfo` and `StyleInfo`
4. Shared tool list and config via `Arc`
5. Declared tool support via `ServerCapabilities`

**Affected:** `src/main.rs` — rewritten. All existing tools (VOICEVOX, Aivis Speech, macOS say) preserved with no API changes.

---

## [v1.0.0] - 2026-02-01

### Added

- Initial release
- VOICEVOX engine support (Port: 50021)
- Aivis Speech engine support (Port: 10101)
- macOS `say` command support
- Default speaker configuration via `config.json`
- `speak-config` GUI tool for speaker management
