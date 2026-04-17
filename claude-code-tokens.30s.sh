#!/usr/bin/env bash

# <xbar.title>Claude Code Token Monitor</xbar.title>
# <xbar.version>v2.1</xbar.version>
# <xbar.author>Carlos (via Claude)</xbar.author>
# <xbar.desc>Monitor Claude Code rate limits from the menubar. Reads live data via Claude Code's statusline API.</xbar.desc>
# <xbar.dependencies>bash,python3</xbar.dependencies>

# ── HOW TO INSTALL ─────────────────────────────────────────────────────────────
# 1. Install xbar: brew install xbar  OR  https://xbarapp.com
# 2. Copy this file to: ~/Library/Application Support/xbar/plugins/
# 3. Make it executable: chmod +x claude-code-tokens.30s.sh
# 4. Set up the statusline bridge (one-time):
#      cp statusline.py ~/.claude/ && chmod +x ~/.claude/statusline.py
#      Then add to ~/.claude/settings.json:
#        "statusLine": { "type": "command", "command": "~/.claude/statusline.py" }
# 5. Open xbar → Refresh All  (or it auto-refreshes every 30s)
#
# The filename encodes the refresh interval: .30s. = every 30 seconds
# ──────────────────────────────────────────────────────────────────────────────

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

python3 << 'PYEOF'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

SESSIONS_DIR = Path.home() / ".claude" / "xbar_sessions"
COST_LEDGER = Path.home() / ".claude" / "xbar_cost_ledger.json"
STALE_SECS = 600        # >10 min = stale
CLEANUP_SECS = 6 * 3600 # remove session files older than 6h


def fmt_k(v):
    if v >= 1_000_000:
        return f"{v / 1_000_000:.1f}M"
    if v >= 1_000:
        return f"{v / 1_000:.1f}k"
    return str(v)


def fmt_pct(v):
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    if isinstance(v, float):
        return f"{v:.1f}"
    return str(v)


def fmt_duration(mins):
    if mins >= 1440:
        d = mins // 1440
        h = (mins % 1440) // 60
        return f"{d}d{h:02d}h"
    if mins >= 60:
        return f"{mins // 60}h{mins % 60:02d}m"
    return f"{mins}m"


def fmt_age(secs):
    if secs < 60:
        return f"{secs}s ago"
    if secs < 3600:
        return f"{secs // 60}m ago"
    return f"{secs // 3600}h{(secs % 3600) // 60:02d}m ago"


def fmt_ms(ms):
    if ms <= 0:
        return ""
    secs = ms / 1000
    if secs < 60:
        return f"{secs:.0f}s"
    mins = secs / 60
    if mins < 60:
        return f"{mins:.0f}m"
    hours = mins / 60
    return f"{hours:.1f}h"


def progress_bar(pct, width=10):
    filled = min(width, int(pct / (100 / width))) if pct > 0 else 0
    return "\u2588" * filled + "\u2591" * (width - filled)


def color_for_pct(pct):
    if pct >= 90: return "#FF3B30"
    if pct >= 70: return "#FF9500"
    if pct >= 40: return "#FFCC00"
    return "#30D158"


def icon_for_pct(pct):
    if pct >= 90: return "\U0001f534"
    if pct >= 70: return "\U0001f7e0"
    if pct >= 40: return "\U0001f7e1"
    return "\U0001f7e2"


def parse_reset(resets_at, now):
    if not resets_at:
        return "N/A", 0
    try:
        if isinstance(resets_at, (int, float)):
            rt = datetime.fromtimestamp(resets_at, tz=timezone.utc)
        else:
            rt = datetime.fromisoformat(str(resets_at).replace("Z", "+00:00"))
        mins = max(0, int((rt - now).total_seconds() / 60))
        if mins > 1440:
            return rt.astimezone().strftime("%b %-d %H:%M"), mins
        return rt.astimezone().strftime("%H:%M"), mins
    except Exception:
        return "N/A", 0


def load_sessions(now):
    """Load all session files, clean up old ones, return list of session dicts."""
    sessions = []

    if SESSIONS_DIR.is_dir():
        for f in SESSIONS_DIR.glob("*.json"):
            try:
                data = json.loads(f.read_text())
                ts = datetime.fromisoformat(data["timestamp"])
                age = (now - ts).total_seconds()
                if age > CLEANUP_SECS:
                    f.unlink(missing_ok=True)
                    continue
                data["_age_secs"] = int(age)
                data["_path"] = f
                sessions.append(data)
            except Exception:
                continue

    return sessions


def main():
    now = datetime.now(timezone.utc)
    sessions = load_sessions(now)

    # ── No data at all ───────────────────────────────────────────────
    if not sessions:
        if not SESSIONS_DIR.is_dir():
            print("\u2B21 CC | color=#888888")
            print("---")
            print("Claude Code statusline not configured | color=gray")
            print("---")
            print("Setup (one-time): | size=12 color=#CCCCCC")
            print("1. cp statusline.py ~/.claude/ | font=Menlo size=11")
            print("2. chmod +x ~/.claude/statusline.py | font=Menlo size=11")
            print('3. Add to ~/.claude/settings.json: | font=Menlo size=11')
            print('   "statusLine": {"type":"command", | font=Menlo size=10 color=#888888')
            print('    "command":"~/.claude/statusline.py"} | font=Menlo size=10 color=#888888')
        else:
            print("\u2B21 CC | color=#888888")
            print("---")
            print("No active sessions | color=gray")
            print("Start a Claude Code session to see stats | color=#555555 size=11")
        print("---")
        print("\U0001f504 Refresh | refresh=true")
        return

    # ── Sort by freshness, newest first ──────────────────────────────
    sessions.sort(key=lambda s: s["_age_secs"])
    newest = sessions[0]
    newest_age = newest["_age_secs"]
    active = [s for s in sessions if s["_age_secs"] <= STALE_SECS]
    n_active = len(active)
    stale = newest_age > STALE_SECS

    # ── Rate limits (account-wide — use newest) ──────────────────────
    rl = newest.get("rate_limits") or {}
    w5 = rl.get("five_hour") or rl.get("5_hour_window") or {}
    w7 = rl.get("seven_day") or rl.get("7_day_window") or {}

    pct5 = round(w5.get("used_percentage", 0), 1)
    pct7 = round(w7.get("used_percentage", 0), 1)
    has_rate_limits = bool(w5.get("resets_at") or w7.get("resets_at"))

    reset5_str, mins5 = parse_reset(w5.get("resets_at"), now)
    reset7_str, mins7 = parse_reset(w7.get("resets_at"), now)

    color5 = color_for_pct(pct5)
    color7 = color_for_pct(pct7)
    icon = "\u23F8" if stale else icon_for_pct(pct5)
    time_left5 = fmt_duration(mins5)
    time_left7 = fmt_duration(mins7)

    # ── Model (from newest) ──────────────────────────────────────────
    model = (newest.get("model") or {}).get("display_name", "?")

    # ── Aggregate cost across all sessions ───────────────────────────
    total_cost = sum((s.get("cost") or {}).get("total_cost_usd", 0) for s in sessions)

    # ══ MENU BAR ═════════════════════════════════════════════════════
    if has_rate_limits:
        sessions_tag = f" [{n_active}]" if n_active > 1 else ""
        print(f"{icon} {fmt_pct(pct5)}%  \u23F1{time_left5}{sessions_tag} | color={color5}")
    else:
        print(f"\u2B21 CC  \u00B7  {model} | color=#888888")

    # ══ DROPDOWN ═════════════════════════════════════════════════════
    print("---")
    session_label = f"{n_active} active" if n_active != 1 else "1 active"
    print(f"Claude Code  \u00B7  {model}  \u00B7  {session_label} | size=13 color=#CCCCCC")

    if has_rate_limits:
        # ── 5-hour window ────────────────────────────────────────────
        print("---")
        bar5 = progress_bar(pct5)
        print(f"{bar5}  {fmt_pct(pct5)}% \u00B7 5h window | font=Menlo size=13 color={color5}")
        print(f"Resets at {reset5_str}  ({time_left5} left) | color=#888888 size=11")

        # ── 7-day window ─────────────────────────────────────────────
        print("---")
        bar7 = progress_bar(pct7)
        print(f"{bar7}  {fmt_pct(pct7)}% \u00B7 7-day window | font=Menlo size=13 color={color7}")
        print(f"Resets at {reset7_str}  ({time_left7} left) | color=#888888 size=11")
    else:
        print("---")
        print("No rate limit data | color=gray")
        print("Rate limits require Claude.ai (Pro/Max) | color=#555555 size=11")

    # ── Per-session details ──────────────────────────────────────────
    print("---")
    for i, s in enumerate(sessions):
        sid = (s.get("session_id") or "?")[:8]
        s_model = (s.get("model") or {}).get("display_name", "?")
        s_age = fmt_age(s["_age_secs"])
        is_stale = s["_age_secs"] > STALE_SECS
        stale_mark = " \u23F8" if is_stale else ""

        cw = s.get("context_window") or {}
        ctx_pct = cw.get("used_percentage") or 0
        s_cost = (s.get("cost") or {}).get("total_cost_usd", 0)
        total_in = cw.get("total_input_tokens", 0)
        total_out = cw.get("total_output_tokens", 0)

        cache_create = s.get("cache_creation_tokens", 0)
        cache_read = s.get("cache_read_tokens", 0)
        duration_ms = s.get("total_duration_ms", 0)
        api_ms = s.get("total_api_duration_ms", 0)
        lines_add = s.get("lines_added", 0)
        lines_rm = s.get("lines_removed", 0)

        color = "#888888" if is_stale else "#CCCCCC"
        print(f"\U0001f5c2  {sid}  \u00B7  {s_model}  \u00B7  {s_age}{stale_mark} | font=Menlo size=12 color={color}")
        print(f"-- \U0001f4e5 In {fmt_k(total_in)}  \U0001f4e4 Out {fmt_k(total_out)}  \U0001f4ca Ctx {ctx_pct}% | font=Menlo size=11")
        if cache_create or cache_read:
            print(f"-- \U0001f4be Cache  \u2191{fmt_k(cache_create)}  \u2193{fmt_k(cache_read)} | font=Menlo size=11")
        if duration_ms:
            dur_str = fmt_ms(duration_ms)
            api_str = fmt_ms(api_ms)
            print(f"-- \u23F1 {dur_str} total  \u2022 {api_str} API | font=Menlo size=11")
        if lines_add or lines_rm:
            print(f"-- \u2795{lines_add}  \u2796{lines_rm} lines | font=Menlo size=11")
        if s_cost > 0:
            print(f"-- \U0001f4b0 ${s_cost:.4f} | font=Menlo size=11")

    # ── Cost by month (from ledger) ─────────────────────────────────
    try:
        ledger = json.loads(COST_LEDGER.read_text()) if COST_LEDGER.exists() else {}
    except Exception:
        ledger = {}

    if ledger:
        print("---")
        # Sort months newest first
        months = sorted(ledger.keys(), reverse=True)
        grand_total = 0
        for month in months:
            sessions_cost = ledger[month]
            month_total = sum(sessions_cost.values())
            grand_total += month_total
            n_sess = len(sessions_cost)
            # Format month: "2026-03" → "Mar 2026"
            try:
                dt = datetime.strptime(month, "%Y-%m")
                label = dt.strftime("%b %Y")
            except Exception:
                label = month
            print(f"\U0001f4b0 {label}    ${month_total:.2f}  ({n_sess} sessions) | font=Menlo size=12")
            # Per-session submenu
            for sid, cost in sorted(sessions_cost.items(), key=lambda x: -x[1]):
                print(f"-- {sid[:8]}  ${cost:.4f} | font=Menlo size=11 color=#888888")
        if len(months) > 1:
            print(f"\U0001f4b0 All time   ${grand_total:.2f} | font=Menlo size=12 color=#CCCCCC")
    elif total_cost > 0:
        print("---")
        print(f"\U0001f4b0 Session cost   ${total_cost:.4f} | font=Menlo size=12")

    # ── Freshness ────────────────────────────────────────────────────
    print("---")
    stale_warn = "  \u26A0\uFE0F stale" if stale else ""
    print(f"\U0001f570  Updated        {fmt_age(newest_age)}{stale_warn} | font=Menlo size=12")

    print("---")
    print("Live data from Claude Code statusline | color=#555555 size=10")
    print("---")
    print("\U0001f504 Refresh | refresh=true")
    print("\U0001f4d6 Claude Code docs | href=https://code.claude.com/docs")


main()
PYEOF
