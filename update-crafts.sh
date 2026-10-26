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
SHORTS=()
LONGS=()
STATUSES=()
while IFS= read -r line; do
  # strip comments
  line="${line%%#*}"
  # trim
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  slug="${line%% *}"
  rest0="${line#* }"
  name="${rest0%% *}"
  rest="${rest0#* }"
  rest="${rest# }"
  SLUGS+=("$slug")
  NAMES+=("$name")
  # first quoted: short category
  tmp="${rest#\"}"
  short="${tmp%%\"*}"
  tmp="${tmp#*\"}"
  tmp="${tmp# }"
  # second quoted: long description
  long="$tmp"
  if [[ "$tmp" == \"* ]]; then
    tmp="${tmp#\"}"
    long="${tmp%%\"*}"
    tmp="${tmp#*\"}"
    tmp="${tmp# }"
  fi
  status="${tmp%% *}"
  [[ -z "$status" ]] && status="dev"
  SHORTS+=("$short")
  LONGS+=("$long")
  DESCS+=("$short")
  STATUSES+=("$status")
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

  # Download hero thumbnail (best effort). FilmCraft uses color.webp upstream.
  mkdir -p "$STAGE_PUBLIC/images/apps/$slug"
  hero_ok=false
  for hero_name in hero.webp color.webp; do
    if curl -fsSL --retry 2 -o "$STAGE_PUBLIC/images/apps/$slug/hero.webp" \
        "https://getartcraft.com/images/apps/$slug/$hero_name" 2>/dev/null; then
      hero_ok=true
      break
    fi
  done
  if ! $hero_ok; then
    warn "could not download hero image for $slug"
    rm -f "$STAGE_PUBLIC/images/apps/$slug/hero.webp"
    rmdir "$STAGE_PUBLIC/images/apps/$slug" 2>/dev/null || true
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
  <title>Crafting Apps: open-source creative tools</title>
  <style>
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: #f2f1ee; color: #0b0b0c; }
    a { color: inherit; }
    .wrap { max-width: 1280px; margin: 0 auto; padding: 0 24px; }
    section { padding: 64px 0; }
    .label { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 11px;
      letter-spacing: .12em; text-transform: uppercase; color: #6b6b6b; }
    h1 { font-size: clamp(2rem, 5vw, 3.5rem); line-height: 1.05; letter-spacing: -.03em;
      margin: 16px 0; font-weight: 600; }
    h2 { font-size: clamp(1.5rem, 3vw, 2.25rem); line-height: 1.1; letter-spacing: -.02em;
      margin: 8px 0 0; font-weight: 600; }
    .lead { max-width: 640px; color: #4a4a4a; line-height: 1.5; margin: 12px 0 24px; }
    .btn { display: inline-flex; align-items: center; gap: 8px; padding: 8px 14px;
      border: 1px solid #0b0b0c; font-family: ui-monospace, monospace; font-size: 11px;
      letter-spacing: .12em; text-transform: uppercase; text-decoration: none; }
    .btn:hover { background: #0b0b0c; color: #f2f1ee; }
    .btn.ghost { border-color: #b8b8b8; color: #0b0b0c; }
    .btn.ghost:hover { background: #0b0b0c; color: #f2f1ee; border-color: #0b0b0c; }

    /* Section 01 top icon grid */
    .icons { display: grid; grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
      gap: 12px; margin-top: 32px; }
    .icon-tile { display: flex; flex-direction: column; align-items: center; gap: 8px;
      text-decoration: none; padding: 12px 8px; border: 1px solid transparent; }
    .icon-tile:hover { border-color: #0b0b0c; background: #fff; }
    .icon-tile img { width: 56px; height: 56px; border-radius: 12px; object-fit: cover; }
    .icon-tile .fallback { width: 56px; height: 56px; border-radius: 12px; display: flex;
      align-items: center; justify-content: center; background: #0b0b0c; color: #f2f1ee;
      font-weight: 700; font-size: 1.4rem; }
    .icon-tile span { font-size: 12px; color: #4a4a4a; }

    /* Section 02 lineup */
    .lineup { display: grid; grid-template-columns: 1fr; gap: 24px; margin-top: 32px; }
    @media (min-width: 900px) { .lineup { grid-template-columns: repeat(2, 1fr); } }
    .card { background: #fff; border: 1px solid #dcdcdc; display: flex; flex-direction: column; }
    .card-head { display: flex; align-items: center; justify-content: space-between;
      padding: 12px 20px; border-bottom: 1px solid #dcdcdc; }
    .card-num { font-family: ui-monospace, monospace; font-size: 12px; font-weight: 700;
      background: #0b0b0c; color: #f2f1ee; padding: 2px 8px; }
    .card-cat { font-family: ui-monospace, monospace; font-size: 11px; letter-spacing: .1em;
      text-transform: uppercase; color: #6b6b6b; }
    .card-hero { aspect-ratio: 16/10; overflow: hidden; background: #e8e8e8; }
    .card-hero a { display: block; height: 100%; }
    .card-hero img { width: 100%; height: 100%; object-fit: cover; display: block;
      transition: transform .4s ease; }
    .card:hover .card-hero img { transform: scale(1.03); }
    .card-body { padding: 0 20px 20px; flex: 1; display: flex; flex-direction: column; }
    .card-icon { width: 72px; height: 72px; border-radius: 14px; margin-top: -36px;
      box-shadow: 0 6px 14px rgba(0,0,0,.2); background: #fff; object-fit: cover; }
    .card-icon-link { display: inline-block; }
    .card-title { font-size: 1.6rem; font-weight: 600; letter-spacing: -.02em; margin: 12px 0 6px; }
    .card-desc { color: #4a4a4a; line-height: 1.5; margin: 0 0 12px; }
    .badges { display: flex; flex-wrap: wrap; gap: 6px; margin: 8px 0 16px; }
    .badge { font-family: ui-monospace, monospace; font-size: 10px; letter-spacing: .1em;
      text-transform: uppercase; padding: 2px 8px; border: 1px solid #dcdcdc; color: #4a4a4a; }
    .badge.status { border-color: #0b0b0c; color: #0b0b0c; }
    .launch { margin-top: auto; font-family: ui-monospace, monospace; font-size: 11px;
      letter-spacing: .12em; text-transform: uppercase; text-decoration: none;
      display: inline-flex; align-items: center; gap: 6px; color: #0b0b0c; }
    .launch:hover { text-decoration: underline; }

    footer { border-top: 1px solid #dcdcdc; padding: 32px 24px; text-align: center;
      color: #6b6b6b; font-size: 13px; }
    footer a { color: #0b0b0c; }
  </style>
</head>
<body>
  <div class="wrap">
    <section>
      <p class="label">01 Crafting Apps</p>
      <h1>Thirteen apps. One craft.</h1>
      <p class="lead">Image editing, vector illustration, video, photography, PDFs, motion graphics,
        page layout, interface design, word processing, audio, presentations, CAD and spreadsheets.
        Native, open-source apps, built in Rust and free to use. This page launches the web builds.</p>
      <div>
        <a class="btn ghost" href="https://discord.gg/artcraft" target="_blank" rel="noopener">Join Discord</a>
        <a class="btn ghost" href="https://github.com/storytold" target="_blank" rel="noopener" style="margin-left:8px;">Browse on GitHub</a>
      </div>
      <div class="icons">
HTML
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    name="${NAMES[$i]}"
    printf '        <a class="icon-tile" href="./%s/">\n' "$slug"
    printf '          <img src="./icons/%s.webp" alt="%s" onerror="this.outerHTML='\''<div class=&quot;fallback&quot;>%s</div>'\''">\n' "$slug" "$name" "${name:0:1}"
    printf '          <span>%s</span>\n' "$name"
    printf '        </a>\n'
  done
  cat <<'HTML'
      </div>
    </section>

    <section>
      <p class="label">02 The lineup</p>
      <h2>Pick a craft to explore</h2>
      <div class="lineup">
HTML
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    name="${NAMES[$i]}"
    desc="${DESCS[$i]}"
    status_code="${STATUSES[$i]}"
    if [[ "$status_code" == "early" ]]; then status_label="Early alpha"; else status_label="In development"; fi
    num=$(printf '%02d' $((i+1)))
    printf '        <article class="card">\n'
    printf '          <div class="card-head"><span class="card-num">%s</span><span class="card-cat">%s</span></div>\n' "$num" "$desc"
    printf '          <div class="card-hero"><a href="./%s/" aria-label="Launch %s">' "$slug" "$name"
    if [[ -f "$STAGE_PUBLIC/images/apps/$slug/hero.webp" ]]; then
      printf '<img src="./images/apps/%s/hero.webp" alt="%s" loading="lazy">' "$slug" "$name"
    else
      printf '<div style="width:100%%;height:100%%;background:#e8e8e8;"></div>'
    fi
    printf '</a></div>\n'
    printf '          <div class="card-body">\n'
    printf '            <a class="card-icon-link" href="./%s/"><img class="card-icon" src="./icons/%s.webp" alt="%s" onerror="this.style.display='\''none'\''"></a>\n' "$slug" "$slug" "$name"
    printf '            <h3 class="card-title">%s</h3>\n' "$name"
    # app description from upstream; reuse crafts desc as short desc already category; add generic
    long="${LONGS[$i]}"
    printf '            <p class="card-desc">%s</p>\n' "$long"
    printf '            <div class="badges"><span class="badge status">%s</span><span class="badge">Installers ready</span><span class="badge">macOS</span><span class="badge">Windows</span><span class="badge">Linux</span><span class="badge">Web</span></div>\n' "$status_label"
    printf '            <a class="launch" href="./%s/">Launch %s →</a>\n' "$slug" "$name"
    printf '          </div>\n'
    printf '        </article>\n'
  done
  cat <<'HTML'
      </div>
    </section>
  </div>

  <footer>
    Craft Apps web builds, auto-updated from GitHub releases.
    &nbsp;·&nbsp;
    <a href="https://github.com/liyu1981/deploy-photocraftweb" target="_blank" rel="noopener">github.com/liyu1981/deploy-photocraftweb</a>
  </footer>
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
