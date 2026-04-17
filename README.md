# Claude Code xbar Plugin

An [xbar](https://xbarapp.com) menubar plugin for macOS that monitors your [Claude Code](https://claude.ai/code) rate limits and session stats in real time.

![xbar menubar showing Claude Code rate limits](https://img.shields.io/badge/xbar-plugin-blue)

## Features

- **Rate limit tracking** — 5-hour and 7-day usage windows with color-coded progress bars
- **Multi-session support** — monitors all active Claude Code sessions simultaneously
- **Per-session details** — input/output tokens, context window usage, cache efficiency, session duration, code churn (lines added/removed)
- **Monthly cost tracking** — cumulative API costs broken down by session and month
- **Auto-refresh** — updates every 30 seconds

## Requirements

- macOS
- [xbar](https://xbarapp.com) (`brew install xbar`)
- [Claude Code](https://claude.ai/code) CLI
- Python 3

## Install

### 1. Install the statusline bridge

This script receives session data from Claude Code and writes it for the xbar plugin to read.

```bash
cp statusline.py ~/.claude/
chmod +x ~/.claude/statusline.py
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.py"
  }
}
```

### 2. Install the xbar plugin

```bash
cp claude-code-tokens.30s.sh ~/Library/Application\ Support/xbar/plugins/
chmod +x ~/Library/Application\ Support/xbar/plugins/claude-code-tokens.30s.sh
```

### 3. Refresh xbar

Open xbar in the menubar and click **Refresh All**, or it will auto-refresh within 30 seconds.

## How it works

Claude Code's [statusline API](https://docs.anthropic.com/en/docs/claude-code) pipes session JSON (rate limits, token counts, costs, model info) to `statusline.py` after each assistant message. The script writes per-session snapshots to `~/.claude/xbar_sessions/`. The xbar plugin reads these snapshots every 30 seconds and renders the menubar display.

## License

MIT
