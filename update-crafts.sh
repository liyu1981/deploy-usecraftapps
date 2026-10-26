#!/usr/bin/env bash
#
# Download the latest web releases for every Craft app and rebuild ./public.
# Pass an app slug and/or tag to pin one app, e.g.:
#
#   ./update-crafts.sh                       # latest upstream releases
#   ./update-crafts.sh photocraft v0.16.0    # pin PhotoCraft, others latest
#
# The upstream repositories are https://github.com/storytold/<app>.
# No build tools are required: each release zip already contains a static site.

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$ROOT_DIR/crafts.txt"
PUBLIC_DIR="$ROOT_DIR/public"
VERSIONS_FILE="$ROOT_DIR/.craft-versions"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in curl unzip find cp mv rm mkdir grep sed; do
  command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

[[ -f "$CONFIG_FILE" ]] || die "missing app list: $CONFIG_FILE"

PIN_APP="${1:-}"
PIN_TAG="${2:-}"
if [[ -n "$PIN_APP" ]]; then
  [[ "$PIN_APP" =~ ^[a-z0-9-]+$ ]] || die "invalid app slug: $PIN_APP"
fi
if [[ -n "$PIN_TAG" ]]; then
  [[ "$PIN_TAG" =~ ^v[0-9] ]] || die "release tag must look like v0.16.0 (got: $PIN_TAG)"
fi

# Load app list.
SLUGS=()
NAMES=()
DESCS=()
while IFS= read -r line; do
  # strip comments
  line="${line%%#*}"
  # trim
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  read -r slug name desc <<<"$line"
  # desc may contain spaces inside quotes; re-parse robustly with eval-free approach:
  # Re-read the original (non-comment) trimmed line via a small parser.
  SLUGS+=("$slug")
  NAMES+=("$name")
  # description is the rest after the second field, with surrounding quotes removed
  rest="${line#* }"
  rest="${rest#* }"
  rest="${rest# }"
  rest="${rest% }"
  rest="${rest#\"}"
  rest="${rest%\"}"
  DESCS+=("$rest")
done < "$CONFIG_FILE"

[[ ${#SLUGS[@]} -gt 0 ]] || die "no apps found in $CONFIG_FILE"

# Map slug -> index
app_index() {
  local target="$1" i
  for i in "${!SLUGS[@]}"; do
    if [[ "${SLUGS[$i]}" == "$target" ]]; then
      echo "$i"; return 0
    fi
  done
  return 1
}

if [[ -n "$PIN_APP" ]]; then
  app_index "$PIN_APP" >/dev/null || die "unknown app slug: $PIN_APP"
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/crafts.XXXXXX")"
STAGE_PUBLIC="$TMP_ROOT/public"
STAGE_TMP="$TMP_ROOT/work"
mkdir -p "$STAGE_PUBLIC" "$STAGE_TMP" "$STAGE_PUBLIC/icons"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

# Resolve latest tag for an app.
resolve_tag() {
  local slug="$1"
  local latest_url
  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/storytold/$slug/releases/latest")" \
    || die "could not query the latest release for $slug (check your network connection)"
  local tag="${latest_url##*/}"
  [[ "$tag" =~ ^v[0-9] ]] || die "unexpected latest-release URL for $slug: $latest_url"
  printf '%s' "$tag"
}

# Quick up-to-date check (only when not pinning).
if [[ -z "$PIN_APP" && -f "$VERSIONS_FILE" ]]; then
  log "Checking for new releases"
  ALL_CURRENT=true
  NEW_META=""
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    tag="$(resolve_tag "$slug")"
    NEW_META+="$slug=$tag"$'\n'
    if ! grep -q "^${slug}=${tag} " "$VERSIONS_FILE" 2>/dev/null; then
      ALL_CURRENT=false
    fi
  done
  if $ALL_CURRENT; then
    log "Already up to date; nothing to do."
    exit 0
  fi
fi

# Track metadata lines for the version file.
META_LINES=()

for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  name="${NAMES[$i]}"

  if [[ -n "$PIN_APP" && "$slug" == "$PIN_APP" && -n "$PIN_TAG" ]]; then
    TAG="$PIN_TAG"
  else
    # If pinning a different app, still resolve latest for this one.
    if [[ -n "$PIN_APP" && "$slug" != "$PIN_APP" ]]; then
      # Could skip re-download if present? Simpler: resolve latest.
      :
    fi
    TAG="$(resolve_tag "$slug")"
  fi

  # Override tag for pinned app even if no pin tag? no.

  VERSION="${TAG#v}"
  ASSET="${slug}-web-${VERSION}.zip"
  BASE_URL="https://github.com/storytold/$slug/releases/download/$TAG"

  log "[$slug] Downloading $ASSET ($TAG)"
  curl -fL --retry 3 --retry-delay 2 --progress-bar \
    -o "$STAGE_TMP/$ASSET" "$BASE_URL/$ASSET" \
    || die "download failed for $slug: $BASE_URL/$ASSET"

  # Verify checksum.
  SHA256="unknown"
  if curl -fsSL --retry 3 -o "$STAGE_TMP/SHA256SUMS.txt" \
      "$BASE_URL/SHA256SUMS.txt" 2>/dev/null; then
    CHECKSUM_LINE="$(grep -E "[[:space:]]${ASSET//./\\.}\$" \
      "$STAGE_TMP/SHA256SUMS.txt" | head -n 1 || true)"
    if [[ -n "$CHECKSUM_LINE" ]]; then
      if command -v sha256sum >/dev/null 2>&1; then
        (cd "$STAGE_TMP" && printf '%s\n' "$CHECKSUM_LINE" | sha256sum -c -) \
          || die "SHA-256 verification failed for $slug $ASSET"
      elif command -v shasum >/dev/null 2>&1; then
        (cd "$STAGE_TMP" && printf '%s\n' "$CHECKSUM_LINE" | shasum -a 256 -c -) \
          || die "SHA-256 verification failed for $slug $ASSET"
      else
        warn "neither sha256sum nor shasum found; skipping checksum verification for $slug"
      fi
      SHA256="${CHECKSUM_LINE%% *}"
    else
      warn "no checksum for $ASSET in SHA256SUMS.txt; skipping verification for $slug"
    fi
  else
    warn "SHA256SUMS.txt not available for $slug; skipping checksum verification"
  fi

  log "[$slug] Extracting release"
  rm -rf "$STAGE_TMP/extract"
  mkdir -p "$STAGE_TMP/extract"
  unzip -q "$STAGE_TMP/$ASSET" -d "$STAGE_TMP/extract"
  SRC_DIR="$(find "$STAGE_TMP/extract" -mindepth 1 -maxdepth 1 -type d \
    -name "${slug}-web-*" -print -quit)"
  [[ -n "$SRC_DIR" ]] || die "release zip for $slug did not contain a ${slug}-web-* folder"
  [[ -f "$SRC_DIR/index.html" ]] || die "release for $slug is missing index.html"

  log "[$slug] Staging static site"
  DEST="$STAGE_PUBLIC/$slug"
  rm -rf "$DEST"
  mkdir -p "$DEST"
  cp -a "$SRC_DIR/." "$DEST/"

  # Download icon (best effort).
  if curl -fsSL --retry 2 -o "$STAGE_PUBLIC/icons/$slug.webp" \
      "https://getartcraft.com/images/apps/$slug/icon.webp" 2>/dev/null; then
    :
  else
    warn "could not download icon for $slug"
    rm -f "$STAGE_PUBLIC/icons/$slug.webp"
  fi

  META_LINES+=("$slug=$TAG sha256=$SHA256")
  rm -f "$STAGE_TMP/$ASSET" "$STAGE_TMP/SHA256SUMS.txt"
done

# Generate landing page.
log "Generating landing page"
INDEX="$STAGE_PUBLIC/index.html"
{
  cat <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Craft Apps</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: #1a1a1a; color: #e6e6e6; }
    header { padding: 48px 24px 24px; text-align: center; }
    header h1 { margin: 0 0 8px; font-size: 2rem; }
    header p { margin: 0; color: #9a9a9a; max-width: 640px; margin-inline: auto; line-height: 1.5; }
    main { max-width: 1200px; margin: 0 auto; padding: 24px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px; }
    .tile { display: flex; flex-direction: column; gap: 10px; padding: 20px; border-radius: 12px;
      background: #262626; color: #e6e6e6; text-decoration: none; border: 1px solid #333;
      transition: transform .12s ease, border-color .12s ease, background .12s ease; }
    .tile:hover { transform: translateY(-2px); border-color: #5a5a5a; background: #2d2d2d; }
    .tile img { width: 48px; height: 48px; border-radius: 10px; object-fit: cover; }
    .tile .icon-fallback { width: 48px; height: 48px; border-radius: 10px; display: flex;
      align-items: center; justify-content: center; background: #3a3a3a; font-weight: 700; font-size: 1.2rem; }
    .tile h2 { margin: 0; font-size: 1.1rem; }
    .tile p { margin: 0; color: #9a9a9a; font-size: .9rem; line-height: 1.4; }
    footer { text-align: center; padding: 32px 24px; color: #666; font-size: .85rem; }
  </style>
</head>
<body>
  <header>
    <h1>Craft Apps</h1>
    <p>Open-source creative tools from ArtCraft, running in your browser. Pick a craft to launch it.</p>
  </header>
  <main>
    <div class="grid">
HTML
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    name="${NAMES[$i]}"
    desc="${DESCS[$i]}"
    printf '      <a class="tile" href="./%s/">\n' "$slug"
    printf '        <img src="./icons/%s.webp" alt="" onerror="this.outerHTML='\''<div class=&quot;icon-fallback&quot;>%s</div>'\''">\n' "$slug" "${name:0:1}"
    printf '        <h2>%s</h2>\n' "$name"
    printf '        <p>%s</p>\n' "$desc"
    printf '      </a>\n'
  done
  cat <<'HTML'
    </div>
  </main>
  <footer>Craft Apps web builds, auto-updated from GitHub releases.</footer>
</body>
</html>
HTML
} > "$INDEX"

# Write version metadata.
printf '%s\n' "${META_LINES[@]}" > "$VERSIONS_FILE.tmp"

# Atomically replace public/.
if [[ -e "$PUBLIC_DIR" && ! -d "$PUBLIC_DIR" ]]; then
  die "$PUBLIC_DIR exists but is not a directory"
fi
OLD_DIR=""
if [[ -d "$PUBLIC_DIR" ]]; then
  OLD_DIR="$(mktemp -d "$ROOT_DIR/.crafts-old.XXXXXX")"
  rmdir "$OLD_DIR"
  mv "$PUBLIC_DIR" "$OLD_DIR"
fi
if ! mv "$STAGE_PUBLIC" "$PUBLIC_DIR"; then
  if [[ -n "$OLD_DIR" ]]; then
    mv "$OLD_DIR" "$PUBLIC_DIR"
  fi
  die "could not move the new site into $PUBLIC_DIR"
fi
STAGE_PUBLIC=""
# move version file into place
mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"
if [[ -n "$OLD_DIR" ]]; then
  rm -rf "$OLD_DIR"
fi
OLD_DIR=""

log "All Craft apps are now in public/"
log "Recorded release details in .craft-versions"
printf '\nNext steps:\n'
printf '  git add public .craft-versions crafts.txt\n'
printf '  git commit -m "Update Craft apps web"\n'
printf '  git push    # Vercel redeploys automatically if the repo is connected\n'
