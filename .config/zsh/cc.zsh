# cc: Claude + Codex conversation picker (fzf) with resume
#
# Usage:
#   cc            - pick from all conversations across both providers
#   cc .          - pick from current project only
#   cc <query>    - pick with fzf query pre-filled
#
# Data sources:
#   ~/.claude/history.jsonl
#   ~/.codex/history.jsonl
#
# Config:
#   DEV_DIR           Root of your projects — optional, strips prefix from project labels
#
# Dependencies: fzf, jq, claude, codex

_cc_check_deps() {
  for cmd in fzf jq; do
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

_cc_format_date() {
  local epoch="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    date -r "$epoch" "+%b %d"
  else
    date -d "@$epoch" "+%b %d"
  fi
}

_cc_collect_claude() {
  command -v claude &>/dev/null || return 0
  local history_file="${CC_CLAUDE_HISTORY_FILE:-$HOME/.claude/history.jsonl}"
  [[ -f "$history_file" ]] || return 0

  jq -Rr '
    fromjson? // empty |
    .sessionId as $sid |
    .project as $proj |
    (.timestamp / 1000 | floor) as $ts |
    (.display // "" | gsub("\t"; " ")) as $msg |
    [$sid, ($proj // ""), ($ts | tostring), $msg] | @tsv
  ' "$history_file" \
  | awk -F'\t' '
    {
      sid = $1; proj = $2; ts = $3 + 0; msg = $4
      if (sid == "" || ts <= 0) next
      if (ts > max_ts[sid]) max_ts[sid] = ts
      if (sid in first_msg) next
      if (msg == "" || substr(msg,1,1) == "<" || substr(msg,1,1) == "{" || substr(msg,1,1) == "/") next
      if (length(msg) > 80) msg = substr(msg, 1, 77) "..."
      if (proj == "") proj = "__NO_CWD__"
      first_proj[sid] = proj
      first_msg[sid] = msg
    }
    END {
      for (sid in first_msg) {
        printf "%d\tclaude\t%s\t%s\t%s\n", max_ts[sid], sid, first_proj[sid], first_msg[sid]
      }
    }
  '
}

_cc_collect_codex() {
  command -v codex &>/dev/null || return 0
  local history_file="${CC_CODEX_HISTORY_FILE:-$HOME/.codex/history.jsonl}"
  [[ -f "$history_file" ]] || return 0

  jq -Rr '
    fromjson? // empty |
    .session_id as $sid |
    (.ts | floor) as $ts |
    (.text // "" | gsub("\t"; " ")) as $msg |
    [$sid, ($ts | tostring), $msg] | @tsv
  ' "$history_file" \
  | awk -F'\t' '
    {
      sid = $1; ts = $2 + 0; msg = $3
      if (sid == "" || ts <= 0) next
      if (ts > max_ts[sid]) max_ts[sid] = ts
      if (sid in first_msg) next
      if (msg == "" || substr(msg,1,1) == "<" || substr(msg,1,1) == "{" || substr(msg,1,1) == "/") next
      if (length(msg) > 80) msg = substr(msg, 1, 77) "..."
      first_msg[sid] = msg
    }
    END {
      for (sid in first_msg) {
        printf "%d\tcodex\t%s\t__NO_CWD__\t%s\n", max_ts[sid], sid, first_msg[sid]
      }
    }
  '
}

_cc_list_sessions() {
  local scope="$1"
  local max_age="$2"

  local now
  local provider sid ppath summary label delta date_str
  now=$(date +%s)

  {
    setopt localoptions no_bg_nice
    _cc_collect_claude &
    _cc_collect_codex &
    wait
  } | sort -t$'\t' -k1,1rn | while IFS=$'\t' read -r epoch provider sid ppath summary; do
    [[ -z "$sid" ]] && continue

    [[ "$ppath" == "__NO_CWD__" ]] && ppath=""

    if [[ "$scope" != "all" ]]; then
      [[ -z "$ppath" || "$ppath" != "$scope" ]] && continue
    fi

    if [[ -n "$max_age" ]]; then
      (( (now - epoch) > max_age )) && continue
    fi

    if [[ -n "$ppath" ]]; then
      label="$ppath"
      label="${label/#$HOME/~}"
      [[ -n "${DEV_DIR:-}" ]] && label="${label/#~\/${DEV_DIR##"$HOME"\/}\//}"
      (( ${#label} > 25 )) && label="…${label: -24}"
    else
      label="-"
    fi

    delta=$(( now - epoch ))
    if (( delta < 60 )); then date_str="just now"
    elif (( delta < 3600 )); then date_str="$(( delta / 60 ))m ago"
    elif (( delta < 86400 )); then date_str="$(( delta / 3600 ))h ago"
    elif (( delta < 172800 )); then date_str="yesterday"
    elif (( delta < 604800 )); then date_str="$(( delta / 86400 ))d ago"
    else date_str=$(_cc_format_date "$epoch")
    fi

    # Visible columns are space-padded into a single tab field so fzf
    # renders them at fixed widths (tabs have unpredictable stop positions).
    printf '%s\t%s\t%s\t%-11s  %-8s  %-25s  %s\n' \
      "$provider" "$sid" "$ppath" "$date_str" "$provider" "$label" "$summary"
  done
}

function cc() {
  _cc_check_deps || return 1

  local scope="all"
  local max_age=""
  local query=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      .)          scope="$(pwd)" ;;
      --today)    max_age=86400 ;;
      --week)     max_age=604800 ;;
      --month)    max_age=2592000 ;;
      *)          query+="${query:+ }$1" ;;
    esac
    shift
  done

  if [[ ! -f "${CC_CLAUDE_HISTORY_FILE:-$HOME/.claude/history.jsonl}" && ! -f "${CC_CODEX_HISTORY_FILE:-$HOME/.codex/history.jsonl}" ]]; then
    echo "No history files found in ~/.claude or ~/.codex"
    return 1
  fi

  local hdr
  hdr=$(printf '%-11s  %-8s  %-25s  %s' 'age' 'src' 'project' 'summary')

  local pick
  pick=$(_cc_list_sessions "$scope" "$max_age" \
    | fzf --height 100% --reverse --prompt="cc: " \
           --no-sort \
           --query="$query" \
           --with-nth=4.. \
           --delimiter=$'\t' \
           --header="$hdr" \
           --preview-window=hidden)

  [[ -z "$pick" ]] && return 0

  local provider session_id project_path
  provider=$(echo "$pick" | cut -f1)
  session_id=$(echo "$pick" | cut -f2)
  project_path=$(echo "$pick" | cut -f3)

  if [[ -n "$project_path" && ! -d "$project_path" ]]; then
    echo "Project directory no longer exists: $project_path"
    return 1
  fi

  if [[ -n "$project_path" ]]; then
    cd "$project_path" || return 1
  fi

  case "$provider" in
    claude) claude -r "$session_id" ;;
    codex)  codex resume "$session_id" ;;
    *)      echo "Unknown provider: $provider"; return 1 ;;
  esac
}
