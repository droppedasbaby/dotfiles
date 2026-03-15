# ds: Dev/tmux session launcher -- pick a directory (zoxide + fzf), create a tmux session named after it
#
# Usage:
#   ds                    - fzf picker: existing sessions, current dir, project directories
#   ds .                  - create/attach session for current directory (no picker)
#   ds <query>            - filter sessions + dirs, auto-select if 1 match, picker if multiple
#   ds --name=<name> ...  - use custom session name
#
# Config:
#   DEV_DIR           Root of your projects -- required, see _lib.zsh
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
  local name="${dir#"$HOME"/}"   # strip ~/ -> gives e.g. dev/my-repo
  name="${name//\//" | "}"
  name="${name//[.:]/-}"
  echo "$name"
}

_ds_create_and_attach() {
  local dir="$1" name="$2"
  if command tmux has-session -t="$name" 2>/dev/null; then
    _ds_attach "$name"
    return 0
  fi
  command tmux new-session -d -s "$name" -c "$dir"
  command tmux split-window -h -t "$name" -c "$dir"
  command tmux select-pane -t "$name":.1
  _ds_attach "$name"
}

# Build the combined list: sessions (tagged), current dir, zoxide + find dirs
_ds_build_list() {
  local -a project_dir_list=("${@}")

  # Existing sessions
  command tmux list-sessions -F "[session] #{session_name}" 2>/dev/null

  # Current directory (always present, deduped later)
  echo "$PWD"

  # Zoxide + find results, filtered to project dirs, junk excluded
  {
    zoxide query -l 2>/dev/null
    local pdir
    for pdir in "${project_dir_list[@]}"; do
      [[ -d "$pdir" ]] || continue
      find "$pdir" -maxdepth 2 -type d -not -name '.*' 2>/dev/null
    done
  } | while IFS= read -r _path; do
    [[ -z "$_path" ]] && continue
    for _pdir in "${project_dir_list[@]}"; do
      [[ -z "$_pdir" ]] && continue
      if [[ "$_path" == "$_pdir" || "$_path" == "$_pdir/"* ]]; then
        echo "$_path"
        break
      fi
    done
  done | command grep -vE '/(node_modules|\.venv[^/]*|__pycache__|\.git|\.tox|\.mypy_cache|\.cache|\.eggs|vendor|build|dist)(/|$)' \
       | awk '!seen[$0]++'
}

function ds() {
  _ds_check_deps || return 1

  if [[ -z "${DEV_DIR:-}" ]]; then
    echo "ds: DEV_DIR must be set" >&2
    return 1
  fi

  # Parse --name=<value>
  local custom_name=""
  local -a args=()
  local arg
  for arg in "$@"; do
    if [[ "$arg" == --name=* ]]; then
      custom_name="${arg#--name=}"
    else
      args+=("$arg")
    fi
  done
  set -- "${args[@]}"

  # shellcheck disable=SC2034  # project_dirs used by zsh array split below
  local project_dirs="${DS_PROJECT_DIRS:-$DEV_DIR}"
  # shellcheck disable=SC2296  # ${(s:x:)} is zsh-specific array splitting syntax
  local -a project_dir_list=("${(s.:.)project_dirs}")

  # Filter empty args (e.g. "ds " with trailing space)
  if [[ $# -eq 1 && -z "$1" ]]; then
    set --
  fi

  # --- ds . --- create/attach for CWD immediately
  if [[ "${1:-}" == "." ]]; then
    local name="${custom_name:-$(_ds_session_name "$PWD")}"
    _ds_create_and_attach "$PWD" "$name"
    return $?
  fi

  # --- ds <query> --- filter against sessions + dirs
  if [[ $# -ge 1 ]]; then
    local query="$1"
    local full_list
    full_list=$(_ds_build_list "${project_dir_list[@]}")

    # Filter the list with fzf
    local -a matches
    matches=("${(@f)$(echo "$full_list" | fzf --filter="$query" --no-sort 2>/dev/null)}")

    # Remove empty elements
    matches=("${(@)matches:#}")

    if [[ ${#matches} -eq 0 ]]; then
      echo "ds: no match for '$query'" >&2
      return 1
    fi

    # Always take the top match -- fzf ranking puts best first
    local pick="${matches[1]}"
    if [[ "$pick" == "[session] "* ]]; then
      _ds_attach "${pick#\[session\] }"
      return 0
    fi
    local name="${custom_name:-$(_ds_session_name "$pick")}"
    _ds_create_and_attach "$pick" "$name"
    return $?
  fi

  # --- ds (no args) --- interactive picker
  local pick
  pick=$(_ds_build_list "${project_dir_list[@]}" \
    | fzf --height 100% --reverse --prompt="ds: " --scheme=history \
  )

  [ -z "$pick" ] && return 0

  if [[ "$pick" == "[session] "* ]]; then
    _ds_attach "${pick#\[session\] }"
    return 0
  fi

  if [ ! -d "$pick" ]; then
    echo "ds: directory does not exist: $pick" >&2
    return 1
  fi

  local name="${custom_name:-$(_ds_session_name "$pick")}"
  _ds_create_and_attach "$pick" "$name"
}
