# speak-mcp

Model Context Protocol (MCP) に対応した音声読み上げサーバーです。
Google Antigravity などの MCP クライアントから、テキスト読み上げ機能を利用可能にします。
バックエンドとして macOS 標準の `say` コマンド、VOICEVOX、および Aivis Speech に対応しています。

## 概要

本サーバーは、LLM からの要求に応じてローカル環境で音声合成を実行します。複数の音声エンジンをサポートしており、用途に応じた使い分けが可能です。

## 対応エンジンと要件

各音声合成エンジンを利用する場合、以下のソフトウェアが別途必要となります。

### 1. macOS 標準音声
macOS に標準搭載されている `say` コマンドを使用します。追加のインストールは不要です。

### 2. VOICEVOX
ローカルで動作するテキスト読み上げソフトウェアです。
HTTP サーバー機能が有効な状態で起動している必要があります。

- **配布元**: [https://voicevox.hiroshiba.jp/](https://voicevox.hiroshiba.jp/)

### 3. Aivis Speech
映像制作等での利用を想定した音声合成エンジンです。
VOICEVOX 互換の API を備えており、本サーバーから利用可能です。

- **公式サイト**: [https://aivis-project.com/](https://aivis-project.com/)
- **GitHub**: [https://github.com/aivis-project/aivisspeech](https://github.com/aivis-project/aivisspeech)

## インストール

**Releases** ページから最新の ZIP ファイルをダウンロードし、解凍して `install.sh` を実行するのが最も簡単です。

```bash
# 解凍したディレクトリで実行
./install.sh
```

### Google Antigravity への設定

`install.sh` の実行後に表示される設定情報を、Google Antigravity の設定に追加してください。

```json
{
  "mcpServers": {
    "speak": {
      "command": "/Users/あなたのユーザー名/speak-mcp/speak-mcp"
    }
  }
}
```

## 設定ツール (speak-config)

デフォルトで使用する話者（Speaker ID）を設定するための GUI ツールが含まれています。
音声エンジンが起動している状態で実行すると、利用可能な話者一覧を取得し、デフォルト設定を `config.json` に保存します。

**使用方法:**

```bash
cd speak-config
cargo run --release
```

ツール上で保存した設定は、`speak-mcp` の起動時に自動的に読み込まれます。
