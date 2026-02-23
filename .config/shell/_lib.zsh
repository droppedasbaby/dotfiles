# _lib: shared functions for dev-env tools
#
# Provides:
#   _load_repo_config <repo_root>   Load per-repo config from $DEV_DIR/configs/repo/
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
