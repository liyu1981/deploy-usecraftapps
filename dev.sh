#!/usr/bin/env bash
# Local preview server for the deployed Craft apps suite.
# Usage: ./dev.sh [port]   (default: 8765)
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-8765}"
cd "$ROOT_DIR"
echo "Serving $ROOT_DIR/public on http://0.0.0.0:$PORT/"
exec python3 -m http.server "$PORT" --directory public --bind 0.0.0.0
