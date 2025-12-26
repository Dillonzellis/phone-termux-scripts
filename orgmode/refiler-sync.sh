#!/usr/bin/env bash
set -u

log() { printf '[refiler-sync] %s\n' "$*"; }
err() { printf '[refiler-sync][ERROR] %s\n' "$*" >&2; }
die() {
  err "$*"
  exit 1
}

REPO_DIR="${1:-${REPO_DIR:-}}"
[ -n "$REPO_DIR" ] || die "Repo path missing. Usage: refiler-sync.sh /path/to/repo (or set REPO_DIR)."

cd "$REPO_DIR" 2>/dev/null || die "Cannot cd to repo dir: $REPO_DIR"

# Sanity check: are we inside a git work tree?
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository: $REPO_DIR"

# Must be on a branch (not detached HEAD)
BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[ -n "$BRANCH" ] || die "Detached HEAD. Checkout a branch (e.g. master/main) before syncing."

log "Repo: $REPO_DIR"
log "Branch: $BRANCH"

# Always fetch first so we know what's on the remote
log "Fetching remote updates..."
git fetch --prune || die "git fetch failed. Check network/remote/auth."

# Determine if working tree is clean (no unstaged or staged changes)
if git diff --quiet && git diff --cached --quiet; then
  CLEAN=1
else
  CLEAN=0
fi

# Pull only if clean (otherwise pull may fail)
if [ "$CLEAN" -eq 1 ]; then
  log "Working tree clean. Attempting fast-forward pull..."
  if ! git pull --ff-only --prune; then
    err "git pull --ff-only failed (likely non-fast-forward). Resolve on laptop, then re-run."
    exit 2
  fi
else
  log "Working tree has local changes. Skipping pull."
fi

# Check for any changes (after pull or local edits) and commit/push if needed
if [ -n "$(git status --porcelain)" ]; then
  log "Changes detected. Staging..."
  git add -A || die "git add failed."

  # Ensure something is actually staged
  if git diff --cached --quiet; then
    log "Nothing staged after add; nothing to commit."
  else
    MSG="refiler sync $(date '+%Y-%m-%d %H:%M:%S %z')"
    log "Committing: $MSG"
    if ! git commit -m "$MSG"; then
      err "git commit failed. If this is unexpected, inspect repo state and try again."
      exit 3
    fi

    log "Pushing..."
    if ! git push; then
      err "git push failed (likely non-fast-forward). Resolve on laptop, then re-run."
      exit 4
    fi
  fi
else
  log "No changes to commit."
fi

log "Sync complete."
exit 0
