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
git lfs pull

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