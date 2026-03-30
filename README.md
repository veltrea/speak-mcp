# speak-mcp

A [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server for text-to-speech.
Enables MCP clients (Claude Desktop, Claude Code, LM Studio, Google Antigravity, etc.) to synthesize speech locally using multiple TTS engines.

> 🇯🇵 [日本語版 README はこちら](README_ja.md)

## Supported Engines

| Engine | Port | Requirements |
|---|---|---|
| **macOS `say`** | — | Built-in. No setup needed. |
| **VOICEVOX** | 50021 | [voicevox.hiroshiba.jp](https://voicevox.hiroshiba.jp/) |
| **Aivis Speech** | 10101 | [aivis-project.com](https://aivis-project.com/) |

## Installation

Download the latest ZIP from the **Releases** page, extract it, and run:

```bash
./install.sh
```

The installer auto-detects your MCP client(s) and configures them interactively.

**Supported clients:** Claude Desktop · Claude Code · Google Antigravity · LM Studio

### Manual MCP Configuration

If you prefer to configure manually, add the following to your client's config:

```json
{
  "mcpServers": {
    "speak": {
      "command": "/path/to/speak-mcp"
    }
  }
}
```

Default install path: `~/speak-mcp/speak-mcp`

## Available Tools

| Tool | Description |
|---|---|
| `speak` | macOS `say` command (macOS only) |
| `speak_voicevox` | VOICEVOX TTS |
| `speak_aivis` | Aivis Speech TTS |

## Building from Source

```bash
git clone https://github.com/veltrea/speak-mcp
cd speak-mcp
./scripts/build.sh
./install.sh
```

Requires [Rust](https://rustup.rs/) (stable).

## speak-config

A GUI tool to set the default speaker ID for VOICEVOX / Aivis Speech.
After TTS engines are running, launch it to pick your preferred voice and save settings.

```bash
open ~/speak-mcp/SpeakConfig.app
```

## License

MIT — see [LICENSE](LICENSE)
