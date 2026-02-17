# Dev session: pick a directory (zoxide + fzf), create a tmux session named after it, split 50/50

# Helper: attach or switch to a tmux session by name
_dev_attach() {
  local name="$1"
  if [ -n "$TMUX" ]; then
    command tmux switch-client -t "$name"
  else
    command tmux attach -t "$name"
  fi
}

# Helper: derive a tmux session name from a directory path
_dev_session_name() {
  local dir="$1"
  if [[ "$dir" == "$HOME/dev/"* ]]; then
    echo "$dir" | sed "s|^$HOME/dev/||" | tr './:' '___'
  else
    echo "$dir" | tr './:' '___'
  fi
}

function dev() {
  # If a directory was passed as an argument, skip fzf
  if [[ $# -eq 1 ]]; then
    local dir="$1"
    # Resolve relative paths
    [[ "$dir" != /* ]] && dir="$(cd "$dir" 2>/dev/null && pwd)"
    if [ ! -d "$dir" ]; then
      echo "Directory does not exist: $1"
      return 1
    fi

    local name=$(_dev_session_name "$dir")
    if command tmux has-session -t="$name" 2>/dev/null; then
      _dev_attach "$name"
      return 0
    fi

    command tmux new-session -d -s "$name" -c "$dir"
    command tmux split-window -h -t "$name" -c "$dir"
    command tmux select-layout -t "$name" even-horizontal
    command tmux select-pane -t "$name":.0
    _dev_attach "$name"
    return 0
  fi

  # Existing sessions (shown first in picker)
  local sessions_display=$(command tmux list-sessions -F "[session] #{session_name}" 2>/dev/null)

  # Directories from zoxide + find
  local dirs=$( { zoxide query -l 2>/dev/null; find ~/dev -maxdepth 1 -type d 2>/dev/null; } \
    | grep -E "^$HOME/dev" \
    | grep -vE '/(node_modules|\.venv[^/]*|__pycache__|\.git|\.tox|\.mypy_cache|\.cache|\.eggs|vendor|build|dist)(/|$)' \
    | sort -u)

  local pick
  pick=$( { [ -n "$sessions_display" ] && echo "$sessions_display"; echo "$dirs"; } \
    | fzf --height 40% --reverse --prompt="dev: " --scheme=history \
           --bind="ctrl-x:execute-silent(command tmux kill-session -t {2})+reload(command tmux list-sessions -F '[session] #{session_name}' 2>/dev/null)" \
           --header="ctrl-x: kill session" )
  [ -z "$pick" ] && return 0

  # If they picked an existing session, attach to it
  if [[ "$pick" == "[session] "* ]]; then
    local name="${pick#\[session\] }"
    _dev_attach "$name"
    return 0
  fi

  local dir="$pick"

  # Validate the directory still exists (zoxide can return stale paths)
  if [ ! -d "$dir" ]; then
    echo "Directory does not exist: $dir"
    return 1
  fi

  local name=$(_dev_session_name "$dir")

  # If session already exists, just attach instead of erroring
  if command tmux has-session -t="$name" 2>/dev/null; then
    _dev_attach "$name"
    return 0
  fi

  # Create new session: left pane
  command tmux new-session -d -s "$name" -c "$dir"
  # Split: right pane
  command tmux split-window -h -t "$name" -c "$dir"
  # Even out the split
  command tmux select-layout -t "$name" even-horizontal
  # Focus left pane
  command tmux select-pane -t "$name":.0

  _dev_attach "$name"
}
