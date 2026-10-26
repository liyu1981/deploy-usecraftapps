#!/usr/bin/env bash
#
# Prepare a Cloudflare Pages deployment in workspace/public/.
#
# 1. Materialise Git LFS assets via prepare-public.sh (into public/).
# 2. Copy public/ into the gitignored workspace/public/ output folder.
# 3. Split any *_bg.wasm above 20 MiB into <= 20 MiB chunks.
# 4. Install the client-side stitching bootstrap and patch index.html.
#
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

bash prepare-public.sh

rm -rf "$ROOT_DIR/workspace/public"
mkdir -p "$ROOT_DIR/workspace"
cp -a "$ROOT_DIR/public" "$ROOT_DIR/workspace/public"

STITCH_SRC="$ROOT_DIR/scripts/stitch-bootstrap.js"
[[ -f "$STITCH_SRC" ]] || { echo "error: missing $STITCH_SRC" >&2; exit 1; }
cp "$STITCH_SRC" "$ROOT_DIR/workspace/public/stitch-bootstrap.js"

# Split oversized WASM files.
while IFS= read -r -d '' wasm; do
  size="$(stat -c %s "$wasm")"
  if (( size > 20971520 )); then
    echo "Splitting $wasm ($size bytes)"
    split -b 20971520 -d -a 3 "$wasm" "$wasm."
    manifest="$wasm.manifest"
    : > "$manifest"
    for chunk in "$wasm".[0-9][0-9][0-9]; do
      [[ -e "$chunk" ]] || continue
      basename "$chunk" >> "$manifest"
    done
    rm -f "$wasm"
  fi
done < <(find "$ROOT_DIR/workspace/public" -type f -name '*_bg.wasm' -print0)

# Patch index.html files: remove stale WASM preload links and inject bootstrap.
python3 - "$ROOT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
out = root / "workspace" / "public"
for index in out.rglob("index.html"):
    text = index.read_text()
    text = re.sub(r'<link[^>]*application/wasm[^>]*>\n?', '', text)
    if "stitch-bootstrap.js" not in text:
        text = text.replace(
            "<script type=\"module\">",
            "<script type=\"module\" src=\"/stitch-bootstrap.js\"></script>\n<script type=\"module\">",
            1,
        )
    index.write_text(text)
PY

# Patch service workers to avoid precaching removed WASM files.
python3 - "$ROOT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
out = root / "workspace" / "public"
for sw in out.rglob("sw.js"):
    text = sw.read_text()
    text = re.sub(r',?\s*"\./[^"]*_bg\.wasm"', '', text)
    sw.write_text(text)
PY

# Cloudflare Pages headers for the prepared output.
cat > "$ROOT_DIR/workspace/public/_headers" <<'HEADERS'
/*
  X-Content-Type-Options: nosniff

/*.wasm
  Content-Type: application/wasm

/*_bg.wasm.manifest
  Cache-Control: no-cache

/stitch-bootstrap.js
  Cache-Control: no-cache

/*_bg.wasm.*
  Content-Type: application/octet-stream
  Cache-Control: public, max-age=31536000, immutable

/*/app/*.part-*
  Content-Type: application/octet-stream
  Cache-Control: public, max-age=31536000, immutable

/*/app/parts.txt
  Cache-Control: no-cache

/*/app/*-web.js
  Cache-Control: no-cache

/*/index.html
  Cache-Control: no-cache

/index.html
  Cache-Control: no-cache
HEADERS

# Validate no oversized files remain.
too_big="$(find "$ROOT_DIR/workspace/public" -type f -size +25M -print)"
if [[ -n "$too_big" ]]; then
  echo "error: files larger than 25 MB remain in workspace/public:" >&2
  printf '%s\n' "$too_big" >&2
  exit 1
fi

echo "Cloudflare Pages output ready: $ROOT_DIR/workspace/public"