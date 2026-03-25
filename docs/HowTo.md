# How To Use speak-mcp

> 🇯🇵 [日本語版はこちら](HowTo_ja.md)

## Quick Start

Extract the ZIP from the **Releases** page and run:

```bash
./install.sh
```

The installer detects your MCP client(s) automatically and guides you through setup.
No Rust or development tools required — the binary is included.

## For Developers

To build from source or customize the code, open this project in your AI-assisted editor and ask it to build:

```bash
./scripts/build.sh
```

Or manually:
```bash
cargo build --release
./install.sh
```

---

**Uninstall**: Delete the `~/speak-mcp` folder and remove the `"speak"` entry from your MCP client config.
