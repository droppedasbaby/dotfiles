# wt: git worktree manager with post-create hooks
#
# Usage:
#   wt                                    fzf picker of all worktrees
#   wt <repo> <branch> [--no-hooks]       create/enter worktree
#   wt <repo> <branch> --remove
#
# Env vars (required):
#   DEV_DIR              Root of your projects — see _lib.zsh
#   WORKTREE_PREFIX      Auto-prepended to bare ticket IDs (e.g. your initials)
# Env vars (derived):
#   CONFIGS_DIR          Defaults to $DEV_DIR/configs — per-repo hooks live here
#
# Dependencies: git
# Optional: pyenv, make, poetry (depending on repo config)

_wt_default_branch() {
  local repo_dir="$1"
  local branch
  branch=$(git -C "$repo_dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [[ -z "$branch" ]]; then
    if git -C "$repo_dir" rev-parse --verify origin/main &>/dev/null; then
      branch="main"
    elif git -C "$repo_dir" rev-parse --verify origin/master &>/dev/null; then
      branch="master"
    fi
  fi
  if [[ -z "$branch" ]]; then
    echo "ERROR: Cannot detect default branch. Run: git remote set-head origin --auto" >&2
    return 1
  fi
  echo "$branch"
}

_wt_usage() {
  cat <<EOF
Usage: wt                                        fzf picker of all worktrees
       wt <repo> <branch>                        create/enter worktree
       wt <repo> <branch> --remove               remove worktree

Sets up a git worktree for development.
Idempotent — creates worktree if missing, fetches + rebases if it exists.
If branch doesn't exist, prompts to create it from origin's default branch.
Runs post-create hooks from \$CONFIGS_DIR/repo/<repo>.zsh if configured.

Arguments:
  repo         Required. Repo directory name under \$DEV_DIR.
  branch       Required. Branch name (e.g. USER/PROJ-1234)
               or ticket ID (e.g. PROJ-1234 — auto-prefixed with \$WORKTREE_PREFIX).

Options:
  --no-hooks   Skip post-create hooks
  --no-sync    Skip fetch + rebase on existing worktrees
  --name       Custom worktree directory name (instead of <repo>-<suffix>)
  --remove     Remove a worktree (offers to delete branch too)

Environment:
  DEV_DIR              Parent directory of your repos.
  WORKTREE_PREFIX      Auto-prepended to branch names without a slash (e.g. USER).
  CONFIGS_DIR          Shared config root (optional; defaults to \$DEV_DIR/configs).
                       Looks for repo/<repo-name>.zsh with WT_POST_CREATE array.

Examples:
  wt                                           # fzf picker — browse all worktrees
  wt my-repo USER/PROJ-1234                    # create/enter worktree
  wt my-repo PROJ-1234                         # auto-prefixed to USER/PROJ-1234
  wt my-repo USER/PROJ-1234 --no-hooks         # skip hooks
  wt my-repo USER/PROJ-1234 --remove           # remove worktree
EOF
}

function wt() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h) _wt_usage; return 0 ;;
    esac
  done

  if [[ -z "${DEV_DIR:-}" ]]; then
    echo "wt: DEV_DIR must be set" >&2
    return 1
  fi
  if [[ -z "${WORKTREE_PREFIX:-}" ]]; then
    echo "wt: WORKTREE_PREFIX must be set" >&2
    return 1
  fi
  local dev_dir="$DEV_DIR"
  if [[ ! -d "$dev_dir" ]]; then
    echo "ERROR: DEV_DIR does not exist: $dev_dir"
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    if ! command -v fzf &>/dev/null; then
      echo "wt: fzf required for picker mode" >&2
      _wt_usage
      return 1
    fi
    local pick
    # shellcheck disable=SC1009,SC1036,SC1058,SC1072,SC1073  # zsh glob qualifier (N)
    pick=$(
      for d in "$dev_dir"/*/(N); do
        [[ -d "$d/.git" ]] || [[ -f "$d/.git" ]] || continue
        git -C "$d" worktree list 2>/dev/null
      done | awk '!seen[$0]++' \
      | fzf --height 100% --reverse --prompt="wt: " \
             --header="enter: cd to worktree")
    [[ -z "$pick" ]] && return 0
    local wt_path="${pick%% *}"
    if [[ -d "$wt_path" ]]; then
      cd "$wt_path"
    else
      echo "Directory does not exist: $wt_path"
      return 1
    fi
    return 0
  fi

  local branch=""
  local repo_name=""
  local build=true
  local custom_name=""
  local sync=true
  local do_remove=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-hooks)  build=false ;;
      --no-sync)   sync=false ;;
      --remove)    do_remove=true ;;
      --name)
        shift
        [[ $# -eq 0 ]] && { echo "ERROR: --name requires a value"; return 1; }
        custom_name="$1"
        ;;
      --help|-h) _wt_usage; return 0 ;;
      -*)        echo "Unknown option: $1"; _wt_usage; return 1 ;;
      *)
        if [[ -z "$repo_name" ]]; then
          repo_name="$1"
        elif [[ -z "$branch" ]]; then
          branch="$1"
        else
          echo "Too many positional arguments"; _wt_usage; return 1
        fi
        ;;
    esac
    shift
  done

  local repo_dir=""

  [[ -z "$branch" ]] && { _wt_usage; return 1; }

  if [[ -z "$repo_name" ]]; then
    echo "ERROR: repo required. Usage: wt <repo> <branch>"
    return 1
  fi
  repo_dir="${dev_dir}/${repo_name}"

  if [[ "$branch" != */* ]]; then
    branch="${WORKTREE_PREFIX}/$branch"
  fi

  local suffix="${branch##*/}"
  local worktree_dir
  if [[ -n "$custom_name" ]]; then
    worktree_dir="${dev_dir}/${custom_name}"
  else
    worktree_dir="${dev_dir}/${repo_name}-${suffix}"
  fi

  if $do_remove; then
    if [[ ! -d "$worktree_dir" ]]; then
      echo "ERROR: Worktree not found at $worktree_dir"
      return 1
    fi
    echo "==> Removing worktree: $worktree_dir"
    if git -C "$repo_dir" worktree remove "$worktree_dir"; then
      echo "    Removed."
      local session_name="${worktree_dir#$HOME/}"
      session_name="${session_name//\//" | "}"
      session_name="${session_name//[.:]/-}"
      if command tmux has-session -t="$session_name" 2>/dev/null; then
        command tmux kill-session -t "$session_name"
        echo "    Killed tmux session: $session_name"
      fi
      local wt_branch
      wt_branch=$(git -C "$repo_dir" branch --list "$branch" 2>/dev/null)
      if [[ -n "$wt_branch" ]]; then
        echo -n "    Delete local branch \"$branch\"? [y/N] "
        read -r confirm
        if [[ "$confirm" == [yY] ]]; then
          git -C "$repo_dir" branch -d "$branch" 2>&1 | sed 's/^/    /'
        fi
      fi
    else
      echo "ERROR: Failed to remove worktree (uncommitted changes?)"
      echo "  Force with:  git -C $repo_dir worktree remove --force $worktree_dir"
      return 1
    fi
    return 0
  fi

  if [[ ! -d "$repo_dir/.git" ]] && [[ ! -f "$repo_dir/.git" ]]; then
    echo "ERROR: Repo not found at $repo_dir"
    return 1
  fi

  local default_branch
  default_branch=$(_wt_default_branch "$repo_dir") || return 1
  local base_ref="origin/$default_branch"

  if [[ -d "$worktree_dir" ]]; then
    echo "==> Worktree already exists at $worktree_dir"
    echo "    Branch: $(git -C "$worktree_dir" branch --show-current)"

    if $sync; then
      if ! git -C "$worktree_dir" diff-index --quiet HEAD -- 2>/dev/null || \
         [[ -n "$(git -C "$worktree_dir" ls-files --others --exclude-standard 2>/dev/null)" ]]; then
        echo "==> Worktree has uncommitted changes — skipping rebase."
        cd "$worktree_dir"
        return 0
      fi

      echo "==> Fetching origin and rebasing on $base_ref..."
      if ! git -C "$worktree_dir" fetch origin; then
        echo "ERROR: git fetch failed (offline? auth expired?)"
        return 1
      fi
      if ! git -C "$worktree_dir" rebase "$base_ref"; then
        git -C "$worktree_dir" rebase --abort
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!!   REBASE FAILED — CONFLICTS FOUND  !!!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        echo "  Worktree: $worktree_dir"
        echo "  Rebase was aborted automatically."
        echo "  Rebase manually:  cd $worktree_dir && git rebase $base_ref"
        echo ""
        return 1
      fi
    else
      echo "    Skipping fetch + rebase (--no-sync)"
    fi
  else
    echo "==> Fetching origin..."
    if ! git -C "$repo_dir" fetch origin; then
      echo "ERROR: git fetch failed (offline? auth expired?)"
      return 1
    fi

    if git -C "$repo_dir" rev-parse --verify "$branch" &>/dev/null || \
       git -C "$repo_dir" rev-parse --verify "origin/$branch" &>/dev/null; then
      echo "==> Creating worktree: $worktree_dir (branch $branch)"
      if ! git -C "$repo_dir" worktree add "$worktree_dir" "$branch" 2>&1; then
        return 1
      fi
    else
      echo "Branch \"$branch\" does not exist."
      echo -n "Create it from $base_ref? [y/N] "
      read -r confirm
      if [[ "$confirm" != [yY] ]]; then
        return 0
      fi
      echo "==> Creating worktree: $worktree_dir (new branch $branch from $base_ref)"
      if ! git -C "$repo_dir" worktree add -b "$branch" "$worktree_dir" "$base_ref" 2>&1; then
        return 1
      fi
    fi
  fi

  _load_repo_config "$repo_dir"

  if ! $build || [[ ${#WT_POST_CREATE[@]} -eq 0 ]]; then
    echo ""
    echo "=========================================="
    echo "Worktree: $worktree_dir"
    echo "Branch:   $(git -C "$worktree_dir" branch --show-current)"
    if [[ ${#WT_POST_CREATE[@]} -eq 0 && "$build" == "true" ]]; then
      echo "    (no hooks for $repo_name)"
    fi
    echo "=========================================="
    cd "$worktree_dir"
    return 0
  fi

  echo ""
  echo "==> Running ${#WT_POST_CREATE[@]} post-create hooks..."
  echo ""

  local failed=()
  local step=0

  for entry in "${WT_POST_CREATE[@]}"; do
    step=$(( step + 1 ))
    local label="${entry%%::*}"
    local cmd="${entry#*::}"

    if [[ "$label" == "$cmd" ]]; then
      label="step $step"
    fi

    echo "[$step/${#WT_POST_CREATE[@]}] $label"
    if (cd "$worktree_dir" && eval "$cmd"); then
      echo "[$step/${#WT_POST_CREATE[@]}] $label ✓"
    else
      echo "[$step/${#WT_POST_CREATE[@]}] $label ✗ FAILED"
      echo "    command: $cmd"
      failed+=("$label")
    fi
    echo ""
  done

  echo "=========================================="
  echo "Worktree: $worktree_dir"
  echo "Branch:   $(git -C "$worktree_dir" branch --show-current)"
  echo ""

  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed hooks: ${failed[*]}"
    return 1
  else
    echo "All hooks passed."
  fi

  echo "=========================================="

  cd "$worktree_dir"
}
