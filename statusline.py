#!/usr/bin/env python3
"""Claude Code statusline script — bridge for xbar token monitor.

Claude Code pipes session JSON to stdin after each assistant message.
This script:
  1. Writes per-session data to ~/.claude/xbar_sessions/{session_id}.json
  2. Prints a one-line status string (for Claude Code's status bar)

Install:
  1. cp statusline.py ~/.claude/ && chmod +x ~/.claude/statusline.py
  2. Add to ~/.claude/settings.json:
     { "statusLine": { "type": "command", "command": "~/.claude/statusline.py" } }
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
SESSIONS_DIR = CLAUDE_DIR / "xbar_sessions"
COST_LEDGER = CLAUDE_DIR / "xbar_cost_ledger.json"


def main():
    data = json.load(sys.stdin)
    session_id = data.get("session_id", "unknown")
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)

    # Collect current_usage cache stats
    cw = data.get("context_window") or {}
    current_usage = cw.get("current_usage") or {}
    cost = data.get("cost") or {}

    # Write per-session snapshot for xbar plugin
    out = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "rate_limits": data.get("rate_limits"),
        "model": data.get("model"),
        "context_window": cw,
        "cost": cost,
        "session_id": session_id,
        "version": data.get("version"),
        "cache_creation_tokens": current_usage.get("cache_creation_input_tokens", 0),
        "cache_read_tokens": current_usage.get("cache_read_input_tokens", 0),
        "total_duration_ms": cost.get("total_duration_ms", 0),
        "total_api_duration_ms": cost.get("total_api_duration_ms", 0),
        "lines_added": cost.get("total_lines_added", 0),
        "lines_removed": cost.get("total_lines_removed", 0),
    }
    session_file = SESSIONS_DIR / f"{session_id}.json"
    tmp = session_file.with_suffix(".tmp")
    try:
        tmp.write_text(json.dumps(out))
        tmp.rename(session_file)
    except OSError:
        pass  # non-fatal

    # Update monthly cost ledger
    cost_usd = cost.get("total_cost_usd", 0)
    if cost_usd > 0:
        month_key = datetime.now(timezone.utc).strftime("%Y-%m")
        try:
            with open(COST_LEDGER) as f:
                ledger = json.load(f)
        except (OSError, json.JSONDecodeError):
            ledger = {}
        if month_key not in ledger:
            ledger[month_key] = {}
        ledger[month_key][session_id] = cost_usd
        tmp_l = COST_LEDGER.with_suffix(".tmp")
        try:
            tmp_l.write_text(json.dumps(ledger))
            tmp_l.rename(COST_LEDGER)
        except OSError:
            pass

    # Output status line for Claude Code UI
    rl = data.get("rate_limits") or {}
    w5 = rl.get("five_hour") or rl.get("5_hour_window") or {}
    w7 = rl.get("seven_day") or rl.get("7_day_window") or {}
    pct5 = round(w5.get("used_percentage", 0), 1)
    pct7 = round(w7.get("used_percentage", 0), 1)
    model = (data.get("model") or {}).get("display_name", "Claude")
    print(f"[{model}] 5h: {pct5}% | 7d: {pct7}%")


if __name__ == "__main__":
    main()
