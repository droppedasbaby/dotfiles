# _lib: shared functions for dev-env tools
#
# Provides:
#   _load_repo_config <repo_root>   Load per-repo config from $DEV_DIR/configs/repo/
#   _env_pick_and_activate <repo_root>  Find, pick, and activate an env (used by nv, tw)
#
# Config lookup:
#   ${CONFIGS_DIR:-$DEV_DIR/configs}/repo/<repo>.zsh
#   Worktrees: strips branch suffix to find the base repo config.

_load_repo_config() {
  local repo_root="$1"
  # shellcheck disable=SC2155  # safe in zsh; local + $() propagates status correctly
  local repo_name=$(basename "$repo_root")
  local config_root="${CONFIGS_DIR:-$DEV_DIR/configs}"
  local config_dir="$config_root/repo"
  local config_file="$config_dir/$repo_name.zsh"

  # Worktree dirs are <repo>-<suffix> — strip suffix to find base repo config
  if [[ -n "$config_dir" && ! -f "$config_file" ]]; then
    local base="$repo_name"
    while [[ "$base" == *-* && ! -f "$config_dir/$base.zsh" ]]; do
      base="${base%-*}"
    done
    [[ -f "$config_dir/$base.zsh" ]] && config_file="$config_dir/$base.zsh"
  fi

  ENV_GLOBS=(); ENV_EXTRA=(); ENV_ACTIVATE=''; ENV_EXCLUDE=()
  TEST_RUN=''; TEST_EXCLUDE=(); TEST_SEARCH_PATTERN='(^tests?$)'; TEST_MAX_DEPTH=8; TEST_TYPE='d'
  # shellcheck disable=SC2034  # used by sourced repo config files
  WT_POST_CREATE=()

  if [[ -n "$config_dir" && -f "$config_file" ]]; then
    # shellcheck disable=SC2034  # used by sourced repo config files
    local REPO_ROOT="$repo_root"
    # shellcheck disable=SC1090  # dynamic path by design
    source "$config_file"
    return 0
  fi

  return 1
}

_env_pick_and_activate() {
  local repo_root="$1"

  _load_repo_config "$repo_root"

  local activate="${ENV_ACTIVATE:-source \$MATCH/bin/activate}"
  local -a results=()

  # Globs first (instant — no process spawn)
  for glob_pattern in "${ENV_GLOBS[@]}"; do
    for p in $repo_root/${~glob_pattern}(N/); do
      results+=("${p#$repo_root/}::${activate/\$MATCH/$p}")
    done
  done

  # Extra paths (poetry, conda)
  for extra in "${ENV_EXTRA[@]}"; do
    local REPO_ROOT="$repo_root"
    local path=$(cd "$repo_root" && eval "$extra" 2>/dev/null)
    if [[ -n "$path" && -d "$path" ]]; then
      results+=("$(basename "$path")::${activate/\$MATCH/$path}")
    fi
  done

  [[ ${#results[@]} -eq 0 ]] && return 1

  local pick
  pick=$(printf '%s\n' "${results[@]}" | awk -F'::' '{print $1}' \
    | fzf --height 100% --reverse --select-1 --exit-0 \
           --prompt="Activate (esc=skip): " \
           --header="Pick env or esc to skip")
  [[ -z "$pick" ]] && return 1

  local cmd=""
  for entry in "${results[@]}"; do
    if [[ "${entry%%::*}" == "$pick" ]]; then
      cmd="${entry#*::}"
      break
    fi
  done

  if [[ -n "$cmd" ]]; then
    local REPO_ROOT="$repo_root"
    eval "$cmd"
    echo "Activated: $pick"
    return 0
  fi
  return 1
}
