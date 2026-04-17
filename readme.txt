# xbar Plugins

Three menubar plugins for macOS via xbar (https://xbarapp.com).

## Install xbar

    brew install xbar

## 1. Claude Code Token Monitor (claude-code-tokens.30s.sh)

Shows Claude Code rate limits (5h and 7-day windows) in the menubar.
Requires a statusline bridge script.

    # Install the statusline bridge
    cp statusline.py ~/.claude/
    chmod +x ~/.claude/statusline.py

    # Add to ~/.claude/settings.json:
    #   "statusLine": { "type": "command", "command": "~/.claude/statusline.py" }

    # Install the xbar plugin
    cp claude-code-tokens.30s.sh ~/Library/Application\ Support/xbar/plugins/
    chmod +x ~/Library/Application\ Support/xbar/plugins/claude-code-tokens.30s.sh

## 2. Bitcoin 24h P&L (btc-pnl.30m.sh)

Shows Bitcoin P&L for 24h, 7d, and 30d in the menubar dropdown.
Uses CoinGecko free API.

    # Set your holdings (or edit the default in the script)
    export XBAR_BTC_AMOUNT=0.5        # in ~/.zshrc
    export XBAR_BTC_CURRENCY=USD       # optional, default USD

    # Install the xbar plugin
    cp btc-pnl.30m.sh ~/Library/Application\ Support/xbar/plugins/
    chmod +x ~/Library/Application\ Support/xbar/plugins/btc-pnl.30m.sh

## 3. Disk Space Monitor (disk-space.1m.sh)

Shows free disk space with colour-coded thresholds.
Dropdown lists recent large files (>100MB in last 7 days).

    cp disk-space.1m.sh ~/Library/Application\ Support/xbar/plugins/
    chmod +x ~/Library/Application\ Support/xbar/plugins/disk-space.1m.sh

## After installing

Open xbar → Refresh All (or plugins auto-refresh on their intervals).
