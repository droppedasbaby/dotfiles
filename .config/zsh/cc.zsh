# cc: Claude + Codex conversation picker (fzf) with resume
#
# Usage:
#   cc            - pick from all conversations across both providers
#   cc .          - pick from current project only
#   cc <query>    - pick with fzf query pre-filled
#   cc --deep     - scan all JSONL files (slow, ~17s first time)
#   cc --api      - resume using personal API key (capi) instead of work account
#
# In fzf:
#   ctrl-e        - scan session JSONL files (3 days)
#   ctrl-r        - scan session JSONL files (7 days)
#   ctrl-a        - scan session JSONL files (all time -- slow)
#   ctrl-p        - filter to current project
#
# Data sources:
#   ~/.claude/history.jsonl        (message history -- always searched)
#   ~/.codex/history.jsonl         (message history -- always searched)
#   ~/.claude/projects/**/*.jsonl  (session content -- searched for PR URLs, ticket IDs)
#
# Config:
#   DEV_DIR           Root of your projects — optional, strips prefix from project labels
#   CC_DATA_PY        Path to cc-data.py (default: alongside this file)
#
# Dependencies: fzf, python3, claude, codex

_cc_check_deps() {
  for cmd in fzf python3; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "cc: requires $cmd but it's not installed" >&2
      return 1
    fi
  done
  if ! command -v claude &>/dev/null && ! command -v codex &>/dev/null; then
    echo "cc: requires at least one of: claude, codex" >&2
    return 1
  fi
}

# Resolve cc-data.py once. The file is shipped alongside cc.zsh; the source
# script may be invoked from anywhere via fzf reload binds.
typeset -g _CC_DATA_PY
_cc_resolve_data() {
  if [[ -n "${CC_DATA_PY:-}" ]]; then
    _CC_DATA_PY="$CC_DATA_PY"
    return
  fi
  # ${(%):-%x} is the path of the currently-sourced file.
  local self_dir="${${(%):-%x}:A:h}"
  if [[ -f "$self_dir/cc-data.py" ]]; then
    _CC_DATA_PY="$self_dir/cc-data.py"
  else
    _CC_DATA_PY="$HOME/dev/work/foundry/dev-env/cc-data.py"
  fi
}
_cc_resolve_data

_cc_format_date() {
  python3 "$_CC_DATA_PY" format-date "$1"
}

_cc_collect_claude() {
  [[ -f "${CC_CLAUDE_HISTORY_FILE:-$HOME/.claude/history.jsonl}" ]] || return 0
  python3 "$_CC_DATA_PY" claude
}

_cc_collect_codex() {
  [[ -f "${CC_CODEX_HISTORY_FILE:-$HOME/.codex/history.jsonl}" ]] || return 0
  python3 "$_CC_DATA_PY" codex
}

_cc_collect_jsonl_keywords() {
  python3 "$_CC_DATA_PY" jsonl-keywords "${1:-3}"
}

_cc_list_sessions() {
  local scope="$1"
  local max_age="${2:-0}"
  local jsonl_days="${3:-0}"
  python3 "$_CC_DATA_PY" list "$scope" "$max_age" "$jsonl_days"
}

function cc() {
  _cc_check_deps || return 1

  local scope="all"
  local max_age=""
  local query=""
  local jsonl_days=0
  local use_api=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      .)          scope="$(pwd)" ;;
      --today)    max_age=86400 ;;
      --week)     max_age=604800 ;;
      --month)    max_age=2592000 ;;
      --deep)     jsonl_days=9999 ;;
      --api)      use_api=1 ;;
      *)          query+="${query:+ }$1" ;;
    esac
    shift
  done

  if [[ ! -f "${CC_CLAUDE_HISTORY_FILE:-$HOME/.claude/history.jsonl}" && ! -f "${CC_CODEX_HISTORY_FILE:-$HOME/.codex/history.jsonl}" ]]; then
    echo "No history files found in ~/.claude or ~/.codex"
    return 1
  fi

  # Direct resume by session ID (full or partial UUID)
  if [[ "$query" =~ ^[0-9a-f]{8}-[0-9a-f]{4} ]]; then
    local sid="$query"
    local ppath
    # Use python to look up the project for this session id from claude history.
    ppath=$(python3 -c "
import json, os, sys
sid = sys.argv[1]
hist = os.environ.get('CC_CLAUDE_HISTORY_FILE', os.path.expanduser('~/.claude/history.jsonl'))
try:
    with open(hist, 'rb') as f:
        for line in f:
            try:
                o = json.loads(line.decode('utf-8', errors='replace'))
            except Exception:
                continue
            if o.get('sessionId', '') == sid and o.get('project'):
                print(o['project']); sys.exit(0)
except OSError:
    pass
" "$sid" 2>/dev/null)
    if [[ -n "$ppath" && -d "$ppath" ]]; then
      cd "$ppath" || return 1
    fi
    if (( use_api )); then capi -r "$sid"; else claude -r "$sid"; fi
    return $?
  fi

  local cc_src="${CC_SRC:-${_CC_DATA_PY:h}/cc.zsh}"
  local cwd
  cwd=$(pwd)
  local hdr
  hdr=$(printf '%-11s  %-8s  %-25s  %s    [^E 3d | ^R 7d | ^A all | ^P project]' 'age' 'src' 'project' 'summary')

  local pick
  pick=$(_cc_list_sessions "$scope" "$max_age" "$jsonl_days" \
    | fzf --height 100% --reverse --prompt="cc: " \
           --tiebreak=index \
           --no-hscroll \
           --query="$query" \
           --with-nth=4 \
           --delimiter=$'\t' \
           --header="$hdr" \
           --preview-window=hidden \
           --bind "ctrl-e:reload(zsh -c 'source $cc_src && _cc_list_sessions ${(q)scope} ${(q)max_age} 3')+change-prompt(cc[3d]: )" \
           --bind "ctrl-r:reload(zsh -c 'source $cc_src && _cc_list_sessions ${(q)scope} ${(q)max_age} 7')+change-prompt(cc[7d]: )" \
           --bind "ctrl-a:reload(zsh -c 'source $cc_src && _cc_list_sessions ${(q)scope} ${(q)max_age} 9999')+change-prompt(cc[all]: )" \
           --bind "ctrl-p:reload(zsh -c 'source $cc_src && _cc_list_sessions ${(q)cwd} ${(q)max_age} ${(q)jsonl_days}')+change-prompt(cc[proj]: )")

  [[ -z "$pick" ]] && return 0

  local provider session_id project_path
  provider=$(print -r -- "$pick" | cut -f1)
  session_id=$(print -r -- "$pick" | cut -f2)
  project_path=$(print -r -- "$pick" | cut -f3)

  if [[ -n "$project_path" ]]; then
    if [[ -d "$project_path" ]]; then
      cd "$project_path" || return 1
    else
      echo "Warning: project directory no longer exists: $project_path (resuming anyway)"
    fi
  fi

  case "$provider" in
    claude) if (( use_api )); then capi -r "$session_id"; else claude -r "$session_id"; fi ;;
    codex)  codex resume "$session_id" ;;
    *)      echo "Unknown provider: $provider"; return 1 ;;
  esac
}
