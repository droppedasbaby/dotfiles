#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
cc-data.py — backend for cc.zsh.

Replaces the jq+awk pipelines with Python so we get:
- multibyte/UTF-8 robustness (no BSD awk crashes)
- type-safe parsing (timestamp/sessionId/display all validated)
- no keyword-aggregation cap (15K cap was dropping late messages)
- cross-provider UUID merge (claude + codex sessions with same id collapse)
- session-emitted-even-if-all-messages-filtered (the 116 missing sessions)

Subcommands match the four cc.zsh helpers 1:1:
    claude              - emit one TSV row per claude session
    codex               - emit one TSV row per codex session
    jsonl-keywords DAYS - scan ~/.claude/projects/*.jsonl for PR URLs / ticket ids
    list SCOPE MAX_AGE JSONL_DAYS - merged, sorted, formatted-for-fzf rows

Output formats match the existing shell functions exactly so cc-test.zsh /
test_cc.py keep passing.

  collect:  epoch \t provider \t sid \t ppath \t summary \t keywords
  list:     provider \t sid \t ppath \t <formatted-blob-for-fzf>
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

PR_URL_RE = re.compile(r'github\.com/[^/"]+/[^/"]+/pull/[0-9]+')
TICKET_RE = re.compile(r"[A-Z]{2,}-[0-9]{3,}")
SUMMARY_MAX = 80              # display column truncation
PER_MSG_KW_MAX = 150          # per-message keyword cap (legacy: keep)
NO_CWD = "__NO_CWD__"


# ---------- shared parsing helpers ----------

def _sanitize(s: str) -> str:
    """Replace tab/newline/CR with spaces. NUL bytes pass through (Python is fine)."""
    return s.replace("\t", " ").replace("\n", " ").replace("\r", " ")


def _coerce_str(v) -> str:
    """display field type confusion: number/array/object all become a string."""
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    if isinstance(v, (int, float, bool)):
        return str(v)
    return json.dumps(v, ensure_ascii=False)


def _valid_ts_seconds(raw, *, prefer_seconds: bool) -> int | None:
    """
    Coerce a timestamp value to integer seconds, or return None to drop the row.

    Real claude history uses milliseconds; codex uses seconds. Both have been
    seen in the wild misspecified (string, ms-vs-s mismatch, scientific
    notation). Strategy: parse as float, sanity-check the era, divide if it
    looks like ms.
    """
    if raw is None:
        return None
    try:
        n = float(raw)
    except (TypeError, ValueError):
        return None
    if not (n == n) or n <= 0:  # NaN or non-positive
        return None

    # Auto-detect ms vs s. Anything > 1e12 is millisecond epoch (year 33000+
    # in seconds is implausible). Anything > 1e15 is bogus (year 31M+).
    if n > 1e15:
        return None
    if prefer_seconds:
        # Codex: input is seconds. If someone fat-fingered ms, divide.
        if n > 1e12:
            n /= 1000
    else:
        # Claude: input is ms. Convert to seconds.
        n /= 1000

    s = int(n)
    # Final sanity bound: 2001-01-01 .. year 9999.
    if s < 978307200 or s > 253402300799:
        return None
    return s


def _valid_sid(raw) -> str | None:
    """sessionId must be a non-empty string. Numbers and other types rejected
    so a stray `{"sessionId": 12345}` doesn't pass through to `claude -r 12345`."""
    if not isinstance(raw, str) or not raw:
        return None
    return raw


def _filtered(msg: str) -> tuple[str | None, str]:
    """
    Apply cc.zsh's first-char filter and slash-command strip.
    Returns (normalized_msg | None, raw_msg). None means the message is filtered
    from BOTH summary and keywords aggregation.
    """
    if not msg:
        return None, msg
    c0 = msg[0]
    if c0 in ("<", "{", ":"):
        return None, msg
    if c0 == "/":
        sp = msg.find(" ")
        if sp == -1:
            return None, msg
        msg = msg[sp + 1:]
        if not msg:
            return None, msg
    return msg, msg


def _truncate_summary(msg: str) -> str:
    if len(msg) <= SUMMARY_MAX:
        return msg
    return msg[: SUMMARY_MAX - 3] + "..."


# ---------- collect ----------

class Session:
    __slots__ = ("max_ts", "first_ts", "project", "first_msg", "kw_parts", "_seen")

    def __init__(self):
        self.max_ts: int = 0
        self.first_ts: int = 0
        self.project: str = ""
        self.first_msg: str | None = None
        self.kw_parts: list[str] = []
        # Dedup: drops messages the user retyped/repasted verbatim. Real
        # history.jsonl has lots of these and they show up as visual repeats
        # in the fzf list.
        self._seen: set[str] = set()


def _read_jsonl(path: Path):
    """Generator yielding parsed dicts. Latin-1 fallback handles raw bytes."""
    if not path.exists():
        return
    with path.open("rb") as fh:
        for raw in fh:
            line = raw.rstrip(b"\n")
            if not line:
                continue
            # JSON spec is UTF-8 but real history files leak Latin-1 bytes.
            # errors='replace' keeps the row instead of dropping it silently.
            try:
                yield json.loads(line.decode("utf-8", errors="replace"))
            except json.JSONDecodeError:
                continue


def collect_claude() -> list[tuple]:
    path = Path(os.environ.get("CC_CLAUDE_HISTORY_FILE", str(Path.home() / ".claude/history.jsonl")))
    return _collect(path, key_sid="sessionId", key_ts="timestamp",
                    key_msg="display", key_proj="project",
                    prefer_seconds=False, provider="claude")


def collect_codex() -> list[tuple]:
    path = Path(os.environ.get("CC_CODEX_HISTORY_FILE", str(Path.home() / ".codex/history.jsonl")))
    return _collect(path, key_sid="session_id", key_ts="ts",
                    key_msg="text", key_proj=None,
                    prefer_seconds=True, provider="codex")


def _collect(path, *, key_sid, key_ts, key_msg, key_proj, prefer_seconds, provider):
    """Returns list of (epoch, provider, sid, project_or_NO_CWD, summary, keywords)."""
    sessions: dict[str, Session] = {}
    order: list[str] = []

    for obj in _read_jsonl(path):
        sid = _valid_sid(obj.get(key_sid))
        if sid is None:
            continue
        ts = _valid_ts_seconds(obj.get(key_ts), prefer_seconds=prefer_seconds)
        if ts is None:
            continue
        msg_raw = _sanitize(_coerce_str(obj.get(key_msg)))
        proj = _coerce_str(obj.get(key_proj)) if key_proj else ""

        sess = sessions.get(sid)
        if sess is None:
            sess = sessions[sid] = Session()
            order.append(sid)
            sess.first_ts = ts
            sess.project = proj
        if ts > sess.max_ts:
            sess.max_ts = ts

        normalized, _ = _filtered(msg_raw)
        if normalized is None:
            continue

        # Skip exact duplicates of any prior message in this session
        # (covers the "first msg also appears verbatim later" case).
        if normalized in sess._seen:
            continue
        sess._seen.add(normalized)

        if sess.first_msg is None:
            # Summary holds the first message (truncated for display).
            # Don't also add it to keywords — that would duplicate it visually.
            sess.first_msg = _truncate_summary(normalized)
        else:
            sess.kw_parts.append(normalized[:PER_MSG_KW_MAX])

    rows = []
    for sid in order:
        sess = sessions[sid]
        # Keep the session even if EVERY message was filtered. The 116 missing
        # sessions all hit this path. Use empty summary as a graceful fallback.
        summary = sess.first_msg if sess.first_msg is not None else ""
        kw = " ".join(sess.kw_parts).replace("\t", " ")
        proj = sess.project if sess.project else NO_CWD
        rows.append((sess.max_ts, provider, sid, proj, summary, kw))
    return rows


# ---------- jsonl keywords ----------

def collect_jsonl_keywords(max_days: int) -> list[tuple[str, str]]:
    """Walk ~/.claude/projects/**/*.jsonl, extract PR URLs and ticket ids per session."""
    root = Path(os.environ.get("HOME", "")) / ".claude/projects"
    if not root.is_dir():
        return []

    cutoff = time.time() - max_days * 86400 if max_days < 9999 else 0
    out: dict[str, list[str]] = {}

    for f in root.rglob("*.jsonl"):
        if cutoff and f.stat().st_mtime < cutoff:
            continue
        sid = f.stem
        try:
            content = f.read_text(errors="replace")
        except OSError:
            continue
        seen: set[str] = set()
        kws: list[str] = []
        for m in PR_URL_RE.findall(content):
            if m not in seen:
                seen.add(m)
                kws.append(m)
        for m in TICKET_RE.findall(content):
            if m not in seen:
                seen.add(m)
                kws.append(m)
        if kws:
            out[sid] = kws

    return [(sid, " ".join(kws)) for sid, kws in out.items()]


# ---------- list ----------

def _format_label(ppath: str, dev_dir: str | None) -> str:
    if not ppath:
        return "-"
    home = os.environ.get("HOME", "")
    label = ppath
    if home and label.startswith(home):
        label = "~" + label[len(home):]
    if dev_dir:
        # Strip DEV_DIR prefix from labels under it.
        rel_dev = dev_dir
        if home and rel_dev.startswith(home):
            rel_dev = "~" + rel_dev[len(home):]
        prefix = rel_dev.rstrip("/") + "/"
        if label.startswith(prefix):
            label = label[len(prefix):]
    if len(label) > 25:
        label = "…" + label[-(25 - 1):]
    return label


def _format_relative_time(now: int, epoch: int) -> str:
    delta = now - epoch
    if delta < 60:
        return "just now"
    if delta < 3600:
        return f"{delta // 60}m ago"
    if delta < 86400:
        return f"{delta // 3600}h ago"
    if delta < 172800:
        return "yesterday"
    if delta < 604800:
        return f"{delta // 86400}d ago"
    return time.strftime("%b %d", time.localtime(epoch))


def list_sessions(scope: str, max_age: int, jsonl_days: int) -> list[str]:
    rows = collect_claude() + collect_codex()
    # Sort newest first.
    rows.sort(key=lambda r: r[0], reverse=True)

    # Cross-provider UUID merge: same sid in both providers → keep one row,
    # union the keywords. Earlier (newer) row wins for everything else.
    merged: dict[str, list] = {}
    for r in rows:
        epoch, provider, sid, ppath, summary, kw = r
        if sid in merged:
            existing = merged[sid]
            existing[5] = (existing[5] + " " + kw).strip()
        else:
            merged[sid] = list(r)
    rows = sorted(merged.values(), key=lambda r: r[0], reverse=True)

    extra_kw = dict(collect_jsonl_keywords(jsonl_days)) if jsonl_days > 0 else {}

    now = int(time.time())
    dev_dir = os.environ.get("DEV_DIR") or None

    out: list[str] = []
    for epoch, provider, sid, ppath, summary, kw in rows:
        if ppath == NO_CWD:
            ppath = ""
        if scope != "all":
            if not ppath or ppath != scope:
                continue
        if max_age > 0 and (now - epoch) > max_age:
            continue
        kw_total = kw
        if sid in extra_kw:
            kw_total = (kw + " " + extra_kw[sid]).strip()

        label = _format_label(ppath, dev_dir)
        date_str = _format_relative_time(now, epoch)

        # Visible-blob layout matches cc.zsh's printf:
        #   %-11s  %-8s  %-25s  %-80s %s
        visible = f"{date_str:<11}  {provider:<8}  {label:<25}  {summary:<80} {kw_total}"
        out.append(f"{provider}\t{sid}\t{ppath}\t{visible}")
    return out


# ---------- main ----------

def emit_collect_rows(rows):
    for epoch, provider, sid, ppath, summary, kw in rows:
        print(f"{epoch}\t{provider}\t{sid}\t{ppath}\t{summary}\t{kw}")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "claude":
        emit_collect_rows(collect_claude())
    elif cmd == "codex":
        emit_collect_rows(collect_codex())
    elif cmd == "jsonl-keywords":
        days = int(argv[2]) if len(argv) > 2 else 3
        for sid, kw in collect_jsonl_keywords(days):
            print(f"{sid}\t{kw}")
    elif cmd == "list":
        scope = argv[2] if len(argv) > 2 else "all"
        max_age = int(argv[3]) if len(argv) > 3 and argv[3] else 0
        jsonl_days = int(argv[4]) if len(argv) > 4 else 0
        for line in list_sessions(scope, max_age, jsonl_days):
            print(line)
    elif cmd == "format-date":
        print(time.strftime("%b %d", time.localtime(int(argv[2]))))
    else:
        print(f"unknown subcommand: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except BrokenPipeError:
        # Reader closed stdin (e.g. `... | head`). Not an error.
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(0)
    except KeyboardInterrupt:
        sys.exit(130)
