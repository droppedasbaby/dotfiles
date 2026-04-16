# cc: Claude + Codex conversation picker (fzf) with resume
#
# Usage:
#   cc            - pick from all conversations across both providers
#   cc .          - pick from current project only
#   cc <query>    - pick with fzf query pre-filled
#   cc --deep     - scan all JSONL files (slow, ~17s first time)
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

zmodload zsh/datetime 2>/dev/null

_cc_format_date() {
  if (( ${+builtins[strftime]} )); then
    strftime "%b %d" "$1"
  elif [[ "$(uname)" == "Darwin" ]]; then
    date -r "$1" "+%b %d"
  else
    date -d "@$1" "+%b %d"
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
    (.display // "" | gsub("[\\t\\n\\r]"; " ")) as $msg |
    [$sid, ($proj // ""), ($ts | tostring), $msg] | @tsv
  ' "$history_file" \
  | awk -F'\t' '
    {
      sid = $1; proj = $2; ts = $3 + 0; msg = $4
      if (sid == "" || ts <= 0) next
      if (ts > max_ts[sid]) max_ts[sid] = ts
      if (msg == "" || substr(msg,1,1) == "<" || substr(msg,1,1) == "{" || substr(msg,1,1) == ":") next
      # Strip slash-command prefix, keep args (e.g. "/flow:fight https://..." -> "fight https://...")
      if (substr(msg,1,1) == "/") {
        sub(/^\/[^ ]*[ ]*/, "", msg)
        if (msg == "") next
      }
      kw = msg
      if (length(kw) > 100) kw = substr(kw, 1, 100)
      if (sid in all_kw) {
        if (length(all_kw[sid]) < 600) all_kw[sid] = all_kw[sid] " " kw
      } else {
        all_kw[sid] = kw
      }
      if (sid in first_msg) next
      if (length(msg) > 80) msg = substr(msg, 1, 77) "..."
      if (proj == "") proj = "__NO_CWD__"
      first_proj[sid] = proj
      first_msg[sid] = msg
    }
    END {
      for (sid in first_msg) {
        kw = (sid in all_kw) ? all_kw[sid] : ""
        gsub(/\t/, " ", kw)
        printf "%d\tclaude\t%s\t%s\t%s\t%s\n", max_ts[sid], sid, first_proj[sid], first_msg[sid], kw
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
    (.text // "" | gsub("[\\t\\n\\r]"; " ")) as $msg |
    [$sid, ($ts | tostring), $msg] | @tsv
  ' "$history_file" \
  | awk -F'\t' '
    {
      sid = $1; ts = $2 + 0; msg = $3
      if (sid == "" || ts <= 0) next
      if (ts > max_ts[sid]) max_ts[sid] = ts
      if (msg == "" || substr(msg,1,1) == "<" || substr(msg,1,1) == "{" || substr(msg,1,1) == ":") next
      if (substr(msg,1,1) == "/") {
        sub(/^\/[^ ]*[ ]*/, "", msg)
        if (msg == "") next
      }
      kw = msg
      if (length(kw) > 100) kw = substr(kw, 1, 100)
      if (sid in all_kw) {
        if (length(all_kw[sid]) < 600) all_kw[sid] = all_kw[sid] " " kw
      } else {
        all_kw[sid] = kw
      }
      if (sid in first_msg) next
      if (length(msg) > 80) msg = substr(msg, 1, 77) "..."
      first_msg[sid] = msg
    }
    END {
      for (sid in first_msg) {
        kw = (sid in all_kw) ? all_kw[sid] : ""
        gsub(/\t/, " ", kw)
        printf "%d\tcodex\t%s\t__NO_CWD__\t%s\t%s\n", max_ts[sid], sid, first_msg[sid], kw
      }
    }
  '
}

_cc_collect_jsonl_keywords() {
  local max_days="${1:-3}"
  local projects_dir="$HOME/.claude/projects"
  [[ -d "$projects_dir" ]] || return 0

  find "$projects_dir" -name "*.jsonl" -type f -mtime "-${max_days}" -print0 2>/dev/null \
  | xargs -0 grep -oHE 'github\.com/[^/"]+/[^/"]+/pull/[0-9]+|[A-Z]{2,}-[0-9]{3,}' 2>/dev/null \
  | awk '{
      line = $0
      if (!match(line, /[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+/)) next
      sid = substr(line, RSTART, RLENGTH)
      if (!match(line, /\.jsonl:/)) next
      term = substr(line, RSTART + 7)
      if (term == "" || (sid SUBSEP term) in seen) next
      seen[sid SUBSEP term] = 1
      if (length(kw[sid]) < 500)
        kw[sid] = (sid in kw) ? kw[sid] " " term : term
    }
    END {
      for (sid in kw) {
        gsub(/\t/, " ", kw[sid])
        print sid "\t" kw[sid]
      }
    }'
}

_cc_list_sessions() {
  local scope="$1"
  local max_age="$2"
  local jsonl_days="${3:-3}"

  # Load supplemental keywords from session JSONL files
  typeset -A extra_kw
  if (( jsonl_days > 0 )); then
    while IFS=$'\t' read -r _sid _kw; do
      extra_kw[$_sid]="$_kw"
    done < <(_cc_collect_jsonl_keywords "$jsonl_days")
  fi

  local now
  local provider sid ppath summary label delta date_str
  now=$(date +%s)

  {
    setopt localoptions no_bg_nice
    _cc_collect_claude &
    _cc_collect_codex &
    wait
  } | sort -t$'\t' -k1,1rn | while IFS=$'\t' read -r epoch provider sid ppath summary keywords; do
    [[ -z "$sid" ]] && continue

    [[ "$ppath" == "__NO_CWD__" ]] && ppath=""

    if [[ "$scope" != "all" ]]; then
      [[ -z "$ppath" || "$ppath" != "$scope" ]] && continue
    fi

    if [[ -n "$max_age" ]]; then
      (( (now - epoch) > max_age )) && continue
    fi

    # Merge keywords from session JSONL content
    if [[ -n "${extra_kw[$sid]:-}" ]]; then
      keywords="$keywords ${extra_kw[$sid]}"
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
    elif (( ${+builtins[strftime]} )); then strftime -s date_str "%b %d" "$epoch"
    else date_str=$(_cc_format_date "$epoch")
    fi

    # Visible columns are space-padded into a single tab field so fzf
    # renders them at fixed widths (tabs have unpredictable stop positions).
    printf '%s\t%s\t%s\t%-11s  %-8s  %-25s  %s\t%s\n' \
      "$provider" "$sid" "$ppath" "$date_str" "$provider" "$label" "$summary" "$keywords"
  done
}

function cc() {
  _cc_check_deps || return 1

  local scope="all"
  local max_age=""
  local query=""
  local jsonl_days=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      .)          scope="$(pwd)" ;;
      --today)    max_age=86400 ;;
      --week)     max_age=604800 ;;
      --month)    max_age=2592000 ;;
      --deep)     jsonl_days=9999 ;;
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
    # Find project path from history
    local ppath
    ppath=$(grep "$sid" "${CC_CLAUDE_HISTORY_FILE:-$HOME/.claude/history.jsonl}" 2>/dev/null | jq -r '.project // ""' | head -1)
    if [[ -n "$ppath" && -d "$ppath" ]]; then
      cd "$ppath" || return 1
    fi
    claude -r "$sid"
    return $?
  fi

  local cc_src="${CC_SRC:-$HOME/.dotfiles/.config/zsh/cc.zsh}"
  local cwd
  cwd=$(pwd)
  local hdr
  hdr=$(printf '%-11s  %-8s  %-25s  %s    [^E 3d | ^R 7d | ^A all | ^P project]' 'age' 'src' 'project' 'summary')

  local pick
  pick=$(_cc_list_sessions "$scope" "$max_age" "$jsonl_days" \
    | fzf --height 100% --reverse --prompt="cc: " \
           --tiebreak=index \
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
    claude) claude -r "$session_id" ;;
    codex)  codex resume "$session_id" ;;
    *)      echo "Unknown provider: $provider"; return 1 ;;
  esac
}
