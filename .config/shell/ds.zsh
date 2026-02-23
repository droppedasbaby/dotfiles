# ds: Dev/tmux session launcher — pick a directory (zoxide + fzf), create a tmux session named after it
#
# Usage:
#   ds              - fzf picker: existing sessions + project directories
#   ds <directory>  - skip picker, open/attach directly
#
# Config:
#   DEV_DIR           Root of your projects — required, see _lib.zsh
#   DS_PROJECT_DIRS   Colon-separated list of directories to scan (default: $DEV_DIR, optional)
#
# Dependencies: tmux, fzf, zoxide

_ds_check_deps() {
  for cmd in tmux fzf zoxide; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ds: requires $cmd but it's not installed" >&2
      return 1
    fi
  done
}

_ds_attach() {
  local name="$1"
  if [ -n "$TMUX" ]; then
    command tmux switch-client -t "$name"
  else
    command tmux attach -t "$name"
  fi
}

_ds_session_name() {
  local dir="$1"
  local name="${dir#"$HOME"/}"   # strip ~/ → gives e.g. dev/my-repo
  name="${name//\//" | "}"
  name="${name//[.:]/-}"
  echo "$name"
}

function ds() {
  _ds_check_deps || return 1

  if [[ -z "${DEV_DIR:-}" ]]; then
    echo "ds: DEV_DIR must be set" >&2
    return 1
  fi
  # shellcheck disable=SC2034  # project_dirs used by zsh array split below
  local project_dirs="${DS_PROJECT_DIRS:-$DEV_DIR}"
  # shellcheck disable=SC2296  # ${(s:x:)} is zsh-specific array splitting syntax
  local -a project_dir_list=("${(s.:.)project_dirs}")

  if [[ $# -eq 1 ]]; then
    local dir="$1"
    [[ "$dir" != /* ]] && dir="$(cd "$dir" 2>/dev/null && pwd)"
    if [ ! -d "$dir" ]; then
      echo "Directory does not exist: $1"
      return 1
    fi

    # shellcheck disable=SC2155  # safe in zsh
    local name=$(_ds_session_name "$dir")
    if command tmux has-session -t="$name" 2>/dev/null; then
      _ds_attach "$name"
      return 0
    fi

    command tmux new-session -d -s "$name" -c "$dir"
    command tmux split-window -h -t "$name" -c "$dir"
    command tmux select-pane -t "$name":.1
    _ds_attach "$name"
    return 0
  fi

  # shellcheck disable=SC2155  # safe in zsh
  local sessions_display=$(command tmux list-sessions -F "[session] #{session_name}" 2>/dev/null)
  local -A existing_sessions
  if [[ -n "$sessions_display" ]]; then
    local _sess_line
    while IFS= read -r _sess_line; do
      [[ -z "$_sess_line" ]] && continue
      existing_sessions[${_sess_line#\[session\] }]=1
    done <<< "$sessions_display"
  fi

  _ds_filter_dirs() {
    local _d _sname
    while IFS= read -r _d; do
      [[ -z "$_d" ]] && continue
      _sname="${_d#"$HOME"/}"
      _sname="${_sname//\//" | "}"
      _sname="${_sname//[.:]/-}"
      [[ -z "${existing_sessions[$_sname]}" ]] && echo "$_d"
    done
  }

  _ds_within_project_dirs() {
    local _path _pdir
    while IFS= read -r _path; do
      [[ -z "$_path" ]] && continue
      for _pdir in "${project_dir_list[@]}"; do
        [[ -z "$_pdir" ]] && continue
        if [[ "$_path" == "$_pdir" || "$_path" == "$_pdir/"* ]]; then
          echo "$_path"
          break
        fi
      done
    done
  }

  local tmpfile tmpfile_all
  tmpfile=$(mktemp)
  tmpfile_all=$(mktemp)

  local pick
  pick=$( {
    [ -n "$sessions_display" ] && echo "$sessions_display"
    {
      zoxide query -l 2>/dev/null
      local pdir
      for pdir in "${project_dir_list[@]}"; do
        [[ -d "$pdir" ]] || continue
        find "$pdir" -maxdepth 2 -type d -not -name '.*' 2>/dev/null
      done
    } | _ds_within_project_dirs \
      | grep -vE '/(node_modules|\.venv[^/]*|__pycache__|\.git|\.tox|\.mypy_cache|\.cache|\.eggs|vendor|build|dist)(/|$)' \
      | awk '!seen[$0]++' \
      | tee "$tmpfile_all" \
      | _ds_filter_dirs \
      | tee "$tmpfile"
  } | fzf --height 100% --reverse --prompt="ds: " --scheme=history \
           --bind="ctrl-x:execute-silent(echo {} | grep -q '^\[session\]' && echo {} | sed 's/^\[session\] //' | xargs -I__ command tmux kill-session -t \"__\")+reload((command tmux list-sessions -F '[session] #{session_name}' 2>/dev/null; command tmux list-sessions -F '#{session_name}' 2>/dev/null > \"$tmpfile\"; awk -v h=\"$HOME\" 'NR==FNR{s[\$0]=1;next}{n=\$0;sub(\"^\"h\"/\",\"\",n);gsub(\"/\",\" | \",n);gsub(/[.:]/,\"-\",n);if(!(n in s))print}' \"$tmpfile\" \"$tmpfile_all\"; rm -f \"$tmpfile\") | awk 'NF')" \
           --header="ctrl-x: kill session (sessions only)" )

  rm -f "$tmpfile" "$tmpfile_all"
  [ -z "$pick" ] && return 0

  if [[ "$pick" == "[session] "* ]]; then
    local name="${pick#\[session\] }"
    _ds_attach "$name"
    return 0
  fi

  local dir="$pick"

  if [ ! -d "$dir" ]; then
    echo "Directory does not exist: $dir"
    return 1
  fi

  # shellcheck disable=SC2155  # safe in zsh
  local name=$(_ds_session_name "$dir")

  if command tmux has-session -t="$name" 2>/dev/null; then
    _ds_attach "$name"
    return 0
  fi

  command tmux new-session -d -s "$name" -c "$dir"
  command tmux split-window -h -t "$name" -c "$dir"
  command tmux select-pane -t "$name":.1

  _ds_attach "$name"
}
