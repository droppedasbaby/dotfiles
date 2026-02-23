#!/usr/bin/env bash

# Sync personal repos in DEV_DIR.

if [[ -z "${DEV_DIR:-}" ]]; then
  echo "sync-repos: DEV_DIR must be set" >&2
  exit 1
fi

CONFIG_FILE="${SYNC_REPOS_CONFIG:-$DEV_DIR/configs/sync-repos.config.sh}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "sync-repos: config not found: $CONFIG_FILE" >&2
  echo "  Create it at $DEV_DIR/configs/sync-repos.config.sh" >&2
  echo "  It must define: PERSONAL_REPOS=(\"repo1\" \"repo2\" ...)" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [[ ! -d "$DEV_DIR" ]]; then
  echo "DEV_DIR does not exist: $DEV_DIR" >&2
  exit 1
fi

if [[ -z "${PERSONAL_REPOS+x}" ]]; then
  echo "PERSONAL_REPOS is not set in sync config" >&2
  exit 1
fi

for required_cmd in git date sed grep; do
  if ! command -v "$required_cmd" >/dev/null 2>&1; then
    echo "Missing required command: $required_cmd" >&2
    exit 1
  fi
done

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

indent() { sed 's/^/  /'; }
ts_compact() { date '+%Y-%m-%d_%H-%M-%S'; }
ts_human() { date '+%Y-%m-%d %H:%M:%S'; }

is_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
has_origin() { git remote get-url origin >/dev/null 2>&1; }
# shellcheck disable=SC1083
has_upstream() { git rev-parse @{u} >/dev/null 2>&1; }
current_branch() { git symbolic-ref --quiet --short HEAD 2>/dev/null || true; }

in_progress_ops() {
  [[ -d .git/rebase-apply || -d .git/rebase-merge || -f .git/MERGE_HEAD || -f .git/CHERRY_PICK_HEAD || -f .git/REVERT_HEAD ]]
}

stage_changes() {
  echo -e "  Staging all changes (including untracked files)"
  git add -A
}

guard_staged_secrets() {
  local bad
  bad="$(git diff --cached --name-only | grep -E '(^|/)(\.env(\..*)?|id_rsa|id_ed25519|.*\.(pem|key|p12|pfx|kdbx))$' || true)"
  if [[ -n "$bad" ]]; then
    echo -e "${RED}✗${NC} Refusing to commit: looks like secret-ish files staged:"
    echo "$bad" | indent
    echo -e "  Fix: unstage/remove those files, or add to .gitignore, or change the denylist."
    return 1
  fi
  return 0
}

sync_personal() {
  local repo="$1"
  echo -e "${YELLOW}[PERSONAL]${NC} Syncing $repo..."
  cd "$DEV_DIR/$repo" || return 1

  if ! is_git_repo; then
    echo -e "${RED}✗${NC} Not a git repo: $repo\n"
    return 1
  fi
  if in_progress_ops; then
    echo -e "${RED}✗${NC} Repo has an in-progress merge/rebase/cherry-pick: $repo"
    echo -e "  Resolve it manually, then rerun.\n"
    return 1
  fi
  if ! has_origin; then
    echo -e "${RED}✗${NC} No origin remote: $repo\n"
    return 1
  fi

  git fetch --prune origin 2>&1 | indent

  local BRANCH
  BRANCH="$(current_branch)"
  if [[ -z "$BRANCH" ]]; then
    # Detached HEAD: still allow snapshot push
    BRANCH="detached"
  fi

  # If upstream not set but origin/BRANCH exists, set upstream automatically
  if ! has_upstream && [[ "$BRANCH" != "detached" ]]; then
    if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
      git branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true
    fi
  fi

  # Integrate remote first (handles uncommitted changes via autostash)
  if has_upstream; then
    if ! git pull --rebase --autostash 2>&1 | indent; then
      echo -e "  ${YELLOW}Rebase/pull failed${NC}; aborting and continuing with snapshot fallback"
      git rebase --abort >/dev/null 2>&1 || true
      git merge --abort >/dev/null 2>&1 || true
    fi
  fi

  # Commit local work (if any)
  stage_changes

  if git diff --cached --quiet; then
    echo -e "  No staged changes; skipping commit"
  else
    if ! guard_staged_secrets; then
      git reset 2>&1 | indent || true
      echo -e "${RED}✗${NC} $repo blocked by secret guard\n"
      return 1
    fi

    local MSG
    MSG="auto-sync: $(ts_human)"
    echo -e "  Committing: $MSG"
    git commit -m "$MSG" 2>&1 | indent
  fi

  local SNAP
  SNAP="snapshots/${BRANCH}/$(ts_compact)"

  # Push: try normal first; if it fails, push snapshot branch so you still get cloud history.
  if [[ "$BRANCH" != "detached" ]]; then
    if has_upstream; then
      if git push 2>&1 | indent; then
        echo -e "${GREEN}✓${NC} $repo pushed successfully\n"
        return 0
      fi
    else
      # No upstream: try to publish/set upstream
      if git push -u origin "$BRANCH" 2>&1 | indent; then
        echo -e "${GREEN}✓${NC} $repo pushed successfully\n"
        return 0
      fi
    fi
  fi

  echo -e "  Normal push failed; pushing snapshot branch: $SNAP"
  if git push origin "HEAD:refs/heads/$SNAP" 2>&1 | indent; then
    echo -e "${GREEN}✓${NC} $repo snapshot pushed successfully\n"
    return 0
  else
    echo -e "${RED}✗${NC} Failed to push snapshot for $repo\n"
    return 1
  fi
}

echo -e "${BLUE}=== Starting Repository Sync ===${NC}\n"

fail=0

echo -e "${BLUE}### Personal Repositories ###${NC}\n"
for repo in "${PERSONAL_REPOS[@]}"; do
  if [[ -d "$DEV_DIR/$repo" ]]; then
    sync_personal "$repo" || fail=1
  else
    echo -e "${RED}✗${NC} $repo directory not found\n"
    fail=1
  fi
done

echo -e "${BLUE}=== Sync Complete ===${NC}"
exit "$fail"
