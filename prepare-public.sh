#!/usr/bin/env bash
#
# Prepare ./public for self-hosting on any static HTTP server (Apache, nginx, ...).
#
# Git LFS stores the large WebAssembly/part files as pointers in the repository.
# A plain clone leaves those pointers in place, so this script materialises them
# before you serve the folder.
#
# Usage:
#   ./prepare-public.sh
#
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi
if ! command -v git-lfs >/dev/null 2>&1; then
  echo "error: git-lfs is required but was not found." >&2
  echo "Install it (https://git-lfs.com) and re-run this script." >&2
  exit 1
fi

if [[ ! -d public ]]; then
  echo "error: ./public does not exist. Run ./update-crafts.sh first." >&2
  exit 1
fi

echo "Pulling Git LFS assets into ./public ..."

# Vercel (and other CI) checkouts may be detached or lack a usable "origin"
# remote, so pull from an explicit URL instead of relying on the default.
REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null || true)"
if [[ -z "$REMOTE_URL" && -n "${VERCEL_GIT_REPO_OWNER:-}" && -n "${VERCEL_GIT_REPO_SLUG:-}" ]]; then
  REMOTE_URL="https://github.com/${VERCEL_GIT_REPO_OWNER}/${VERCEL_GIT_REPO_SLUG}.git"
fi
# Convert SSH URLs to HTTPS so anonymous fetch works in CI.
if [[ "$REMOTE_URL" == git@github.com:* ]]; then
  REMOTE_URL="https://github.com/${REMOTE_URL#git@github.com:}"
fi
if [[ -z "$REMOTE_URL" ]]; then
  REMOTE_URL="https://github.com/liyu1981/deploy-usecraftapps.git"
fi

# Ensure LFS smudge/clean filters are configured in this checkout (Vercel
# build images ship the binary but may not have run `git lfs install`).
git lfs install --local >/dev/null 2>&1 || git lfs install >/dev/null 2>&1 || true

git lfs pull "$REMOTE_URL"

# Make sure no LFS pointer files are left behind in the served folder.
POINTERS="$(grep -rl 'version https://git-lfs.github.com/spec/v1' public 2>/dev/null || true)"
if [[ -n "$POINTERS" ]]; then
  echo "error: LFS pointer files remain in ./public:" >&2
  printf '%s\n' "$POINTERS" >&2
  echo "Run 'git lfs checkout' manually and check the files above." >&2
  exit 1
fi

echo "Ready. Serve the ./public directory with any static HTTP server."
echo "Example (Apache/Nginx document root): point the vhost at $ROOT_DIR/public"
echo "Example (local): python3 -m http.server 8765 --directory public"