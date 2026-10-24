#!/usr/bin/env bash
#
# Cron-friendly updater:
#   1. pulls the latest commit from origin
#   2. downloads the latest PhotoCraft web release into public/
#   3. commits and pushes only when the release actually changed
#
# Intended for a crontab entry such as:
#   0 4 * * * /home/yli/deploy-photocraftweb/cron-update.sh >> /home/yli/photocraft-update.log 2>&1
#
# The repository must have an "origin" remote and a configured git identity.

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$ROOT_DIR/.photocraft-version"
cd "$ROOT_DIR"

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { printf '%s ERROR: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; exit 1; }

# Avoid overlapping runs if a download is slow.
if command -v flock >/dev/null 2>&1; then
  exec 9>"${TMPDIR:-/tmp}/photocraft-cron-update.lock"
  if ! flock -n 9; then
    log "Another update is already running; exiting."
    exit 0
  fi
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$ROOT_DIR is not a git repository"
git config user.name >/dev/null 2>&1 || die "git user.name is not configured"
git config user.email >/dev/null 2>&1 || die "git user.email is not configured"
git remote get-url origin >/dev/null 2>&1 || die "git remote 'origin' is not configured"
[[ -x "$ROOT_DIR/update-photocraft.sh" ]] || die "update-photocraft.sh is missing or not executable"

BRANCH="$(git symbolic-ref --quiet --short HEAD)" || die "HEAD is detached; check out a branch"
[[ -n "$BRANCH" ]] || die "could not determine the current branch"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  die "working tree has uncommitted tracked changes; refusing to update"
fi

log "Fetching origin/$BRANCH"
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git fetch --prune origin "$BRANCH"
  git pull --ff-only origin "$BRANCH"
else
  log "origin/$BRANCH does not exist yet; skipping pull"
fi

read_meta() {
  if [[ -f "$VERSION_FILE" ]]; then
    sed '/^updated=/d' "$VERSION_FILE"
  fi
}
OLD_META="$(read_meta)"

log "Checking for a new PhotoCraft release"
"$ROOT_DIR/update-photocraft.sh"

# The update script always refreshes the "updated" timestamp. If the release
# metadata is unchanged, restore the old file so cron does not commit daily.
if [[ "$(read_meta)" == "$OLD_META" ]]; then
  git checkout -- "$VERSION_FILE" 2>/dev/null || true
fi

if [[ -z "$(git status --porcelain --untracked-files=no)" ]]; then
  log "Already up to date; nothing to commit."
  exit 0
fi

TAG="$(sed -n 's/^tag=//p' "$VERSION_FILE" | head -n 1)"
TAG="${TAG:-unknown}"

git add -A -- public .photocraft-version
if git diff --cached --quiet; then
  log "Already up to date; nothing to commit."
  exit 0
fi

log "Committing PhotoCraft $TAG"
git commit -m "Update PhotoCraft web to $TAG"

log "Pushing to origin/$BRANCH"
if ! git push origin "$BRANCH"; then
  log "Push rejected; rebasing on origin/$BRANCH and retrying once"
  git pull --rebase origin "$BRANCH"
  git push origin "$BRANCH"
fi

log "Update complete: PhotoCraft $TAG pushed to origin/$BRANCH"
