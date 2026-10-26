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

SLUGS=()
NAMES=()
DESCS=()
SHORTS=()
LONGS=()
STATUSES=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  slug="${line%% *}"
  rest0="${line#* }"
  name="${rest0%% *}"
  rest="${rest0#* }"
  rest="${rest# }"
  tmp="${rest#\"}"
  short="${tmp%%\"*}"
  tmp="${tmp#*\"}"
  tmp="${tmp# }"
  long="$tmp"
  if [[ "$tmp" == \"* ]]; then
    tmp="${tmp#\"}"
    long="${tmp%%\"*}"
    tmp="${tmp#*\"}"
    tmp="${tmp# }"
  fi
  status="${tmp%% *}"
  [[ -z "$status" ]] && status="dev"
  SLUGS+=("$slug")
  NAMES+=("$name")
  SHORTS+=("$short")
  LONGS+=("$long")
  DESCS+=("$short")
  STATUSES+=("$status")
done < "$CONFIG_FILE"

[[ ${#SLUGS[@]} -gt 0 ]] || die "no apps found in $CONFIG_FILE"

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

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

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

if [[ -z "$PIN_APP" && -f "$VERSIONS_FILE" ]]; then
  log "Checking for new releases"
  ALL_CURRENT=true
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    tag="$(resolve_tag "$slug")"
    if ! grep -q "^${slug}=${tag} " "$VERSIONS_FILE" 2>/dev/null; then
      ALL_CURRENT=false
    fi
  done
  if $ALL_CURRENT; then
    log "Already up to date; nothing to do."
    exit 0
  fi
fi

META_LINES=()

for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  name="${NAMES[$i]}"

  if [[ -n "$PIN_APP" && "$slug" == "$PIN_APP" && -n "$PIN_TAG" ]]; then
    TAG="$PIN_TAG"
  else
    TAG="$(resolve_tag "$slug")"
  fi

  VERSION="${TAG#v}"
  ASSET="${slug}-web-${VERSION}.zip"
  BASE_URL="https://github.com/storytold/$slug/releases/download/$TAG"

  log "[$slug] Downloading $ASSET ($TAG)"
  curl -fL --retry 3 --retry-delay 2 --progress-bar \
    -o "$STAGE_TMP/$ASSET" "$BASE_URL/$ASSET" \
    || die "download failed for $slug: $BASE_URL/$ASSET"

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

  if curl -fsSL --retry 2 -o "$STAGE_PUBLIC/icons/$slug.webp" \
      "https://getartcraft.com/images/apps/$slug/icon.webp" 2>/dev/null; then
    :
  else
    warn "could not download icon for $slug"
    rm -f "$STAGE_PUBLIC/icons/$slug.webp"
  fi

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
    :root {
      --bg:#f2f1ee; --bg-raised:#faf9f7; --bg-sunken:#e9e8e4;
      --ink:#101014; --ink-strong:#000; --muted:#1010149e; --faint:#1010146b;
      --line:#10101429; --line-strong:#10101466; --accent:#2d81ff; --accent-ink:#1659c4;
      --invert-bg:#101014; --invert-fg:#f2f1ee;
      color-scheme: light;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg:#121316; --bg-raised:#101014; --bg-sunken:#060607;
        --ink:#f2f1ee; --ink-strong:#fff; --muted:#f2f1ee99; --faint:#f2f1ee61;
        --line:#f2f1ee26; --line-strong:#f2f1ee66; --accent:#2d81ff; --accent-ink:#74aaff;
        --invert-bg:#fff; --invert-fg:#0b0b0c;
        color-scheme: dark;
      }
    }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: var(--bg); color: var(--ink); }
    a { color: inherit; text-decoration: none; }
    .frame { max-width: 1280px; margin: 0 auto; border-left: 1px solid var(--line);
      border-right: 1px solid var(--line); position: relative; }
    .inner { padding: 0 24px; }
    .top-rule { position: absolute; top: 0; left: 0; right: 0; height: 1px;
      background: var(--line); z-index: 20; }
    .tick { pointer-events: none; width: 11px; height: 11px; position: absolute; }
    .tick:before, .tick:after { content: ""; background: var(--line-strong); position: absolute; }
    .tick:before { width: 1px; top: 0; bottom: 0; left: 5px; }
    .tick.tick-half:before { top: 5px; }
    .tick:after { height: 1px; top: 5px; left: 0; right: 0; }

    /* Section 01 */
    .s1 { padding: 56px 0; border-bottom: 1px solid var(--line); }
    .s1-row { display: block; }
    @media (min-width: 1280px) { .s1-row { display: flex; align-items: center; justify-content: space-between; gap: 48px; } }
    .s1-text { min-width: 0; }
    .eyebrow { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 11px;
      letter-spacing: .12em; text-transform: uppercase; color: var(--faint); }
    .eyebrow .num { color: var(--faint); }
    h1 { font-size: clamp(2rem, 5vw, 3.5rem); line-height: 1.02; letter-spacing: -.035em;
      margin: 16px 0; font-weight: 500; color: var(--ink-strong); }
    h1 .accent { color: var(--accent-ink); white-space: nowrap; }
    .lead { max-width: 560px; color: var(--muted); line-height: 1.5; margin: 16px 0 24px; font-size: 1.05rem; }
    .btns { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 24px; }
    .btn { display: inline-flex; align-items: center; gap: 8px; height: 44px; padding: 0 20px;
      border: 1px solid var(--line-strong); background: var(--bg); color: var(--ink);
      font-family: ui-monospace, monospace; font-size: 11px; letter-spacing: .12em;
      text-transform: uppercase; }
    .btn:hover { border-color: var(--ink); }
    .btn.primary { background: var(--invert-bg); color: var(--invert-fg); border-color: var(--invert-bg); }

    .icon-grid { margin-top: 32px; display: grid; grid-template-columns: repeat(4, 1fr);
      gap: 12px 8px; }
    @media (min-width: 640px) { .icon-grid { grid-template-columns: repeat(7, 1fr); gap: 12px 16px; } }
    @media (min-width: 1280px) { .icon-grid { margin-top: 0; width: 480px; flex-shrink: 0;
      display: flex; flex-wrap: wrap; justify-content: center; gap: 12px 20px; } }
    .icon-tile { display: flex; flex-direction: column; align-items: center; gap: 6px;
      width: 72px; }
    @media (min-width: 640px) { .icon-tile { width: 80px; } }
    .icon-tile img { width: 56px; height: 56px; border-radius: 12px; object-fit: cover;
      box-shadow: 0 6px 14px rgba(0,0,0,.2); transition: transform .25s ease; }
    @media (min-width: 640px) { .icon-tile img { width: 80px; height: 80px; } }
    .icon-tile:hover img { transform: translateY(-4px); }
    .icon-tile .fallback { width: 56px; height: 56px; border-radius: 12px; display: flex;
      align-items: center; justify-content: center; background: var(--invert-bg);
      color: var(--invert-fg); font-weight: 700; font-size: 1.3rem; }
    @media (min-width: 640px) { .icon-tile .fallback { width: 80px; height: 80px; } }
    .icon-tile span { font-size: 12px; font-weight: 500; color: var(--muted); }
    .icon-tile:hover span { color: var(--accent-ink); }

    /* Section 02 */
    .sticky-bar { position: sticky; top: 0; z-index: 30; border-top: 1px solid var(--line);
      border-bottom: 1px solid var(--line); background: var(--bg); backdrop-filter: blur(8px); }
    .sticky-inner { display: flex; align-items: center; justify-content: space-between;
      gap: 16px; padding: 12px 24px; max-width: 1280px; margin: 0 auto; }
    .sticky-title { font-family: ui-monospace, monospace; font-size: 11px; letter-spacing: .12em;
      text-transform: uppercase; color: var(--muted); }
    .sticky-title .num { color: var(--faint); margin-right: 8px; }
    .sticky-sub { font-family: ui-monospace, monospace; font-size: 11px; letter-spacing: .12em;
      text-transform: uppercase; color: var(--faint); display: none; }
    @media (min-width: 640px) { .sticky-sub { display: block; } }

    .lineup { display: grid; grid-template-columns: 1fr; gap: 1px; background: var(--line); }
    @media (min-width: 640px) { .lineup { grid-template-columns: repeat(2, 1fr); } }
    @media (min-width: 1280px) { .lineup { grid-template-columns: repeat(4, 1fr); } }

    .card { background: var(--bg); display: flex; flex-direction: column; min-height: 100%; }
    .card-head { display: flex; align-items: center; justify-content: space-between;
      gap: 12px; padding: 12px 20px; border-bottom: 1px solid var(--line); }
    .card-num { font-family: ui-monospace, monospace; font-size: 12px; font-weight: 700;
      background: var(--accent-ink); color: var(--invert-fg); padding: 2px 8px; }
    @media (prefers-color-scheme: dark) { .card-num { color: #000; } }
    .card-cat { font-family: ui-monospace, monospace; font-size: 11px; letter-spacing: .1em;
      text-transform: uppercase; color: var(--faint); white-space: nowrap; overflow: hidden;
      text-overflow: ellipsis; }
    .card-hero { aspect-ratio: 16/10; overflow: hidden; background: var(--bg-sunken); position: relative; z-index: 1; }
    .card-icon { position: relative; z-index: 2; }
    .card-hero img { width: 100%; height: 100%; object-fit: cover; display: block;
      transition: transform .5s ease; }
    .card:hover .card-hero img { transform: scale(1.03); }
    .card-body { padding: 0 20px 20px; flex: 1; display: flex; flex-direction: column; }
    .card-icon { width: 72px; height: 72px; border-radius: 14px; margin-top: -36px;
      box-shadow: 0 6px 14px rgba(0,0,0,.28); background: var(--bg-raised); object-fit: cover;
      border: 1px solid var(--line); }
    .card-title { font-size: 1.6rem; font-weight: 500; letter-spacing: -.02em; margin: 14px 0 6px;
      color: var(--ink-strong); }
    .card-desc { color: var(--muted); line-height: 1.5; margin: 0 0 12px; font-size: .95rem; }
    .badges { display: flex; flex-wrap: wrap; gap: 6px; margin: 8px 0 16px; }
    .badge { font-family: ui-monospace, monospace; font-size: 10px; letter-spacing: .1em;
      text-transform: uppercase; padding: 2px 8px; border: 1px solid var(--line); color: var(--muted); }
    .badge.status { border-color: var(--line-strong); color: var(--ink); }
    .launch { margin-top: auto; font-family: ui-monospace, monospace; font-size: 11px;
      letter-spacing: .12em; text-transform: uppercase; color: var(--muted);
      display: inline-flex; align-items: center; gap: 6px; }
    .card:hover .launch { color: var(--ink); }

    footer { border-top: 1px solid var(--line); padding: 32px 24px; text-align: center;
      color: var(--faint); font-size: 13px; }
    footer a { color: var(--ink); }
  </style>
</head>
<body>
  <div class="frame">
    <div class="top-rule"></div>
    <span class="tick tick-half" style="top:-5px;left:-6px;"></span>
    <span class="tick tick-half" style="top:-5px;right:-6px;"></span>
  <section class="s1">
    <div class="inner">
      <div class="s1-row">
        <div class="s1-text">
          <p class="eyebrow"><span class="num">01</span> Crafting Apps</p>
          <h1>Thirteen apps. <span class="accent">One craft.</span></h1>
          <p class="lead">Image editing, vector illustration, video, photography, PDFs, motion graphics,
            page layout, interface design, word processing, audio, presentations, CAD and spreadsheets.
            Native, open-source apps from the ArtCraft team, built in Rust and free to use.
            This page launches the web builds.</p>
          <div class="btns">
            <a class="btn" href="https://discord.gg/artcraft" target="_blank" rel="noopener">Join Discord</a>
            <a class="btn" href="https://github.com/storytold" target="_blank" rel="noopener">Browse on GitHub</a>
          </div>
        </div>
        <div class="icon-grid">
HTML
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    name="${NAMES[$i]}"
    printf '          <a class="icon-tile" href="./%s/"><img src="./icons/%s.webp" alt="%s" onerror="this.outerHTML='\''<div class=&quot;fallback&quot;>%s</div>'\''"><span>%s</span></a>\n' "$slug" "$slug" "$name" "${name:0:1}" "$name"
  done
  cat <<'HTML'
        </div>
      </div>
    </div>
  </section>

  <div class="sticky-bar">
    <div class="sticky-inner">
      <p class="sticky-title"><span class="num">02</span> / The lineup</p>
      <p class="sticky-sub">Pick a craft to explore</p>
    </div>
  </div>

  <div class="inner" style="padding-top:0;padding-bottom:48px;">
    <div class="lineup">
HTML
  for i in "${!SLUGS[@]}"; do
    slug="${SLUGS[$i]}"
    name="${NAMES[$i]}"
    cat="${DESCS[$i]}"
    long="${LONGS[$i]}"
    status_code="${STATUSES[$i]}"
    if [[ "$status_code" == "early" ]]; then status_label="Early alpha"; else status_label="In development"; fi
    num=$(printf '%02d' $((i+1)))
    printf '      <a class="card" href="./%s/">\n' "$slug"
    printf '        <div class="card-head"><span class="card-num">%s</span><span class="card-cat">%s</span></div>\n' "$num" "$cat"
    printf '        <div class="card-hero">'
    if [[ -f "$STAGE_PUBLIC/images/apps/$slug/hero.webp" ]]; then
      printf '<img src="./images/apps/%s/hero.webp" alt="%s" loading="lazy">' "$slug" "$name"
    fi
    printf '</div>\n'
    printf '        <div class="card-body">\n'
    printf '          <img class="card-icon" src="./icons/%s.webp" alt="%s" onerror="this.style.display='\''none'\''">\n' "$slug" "$name"
    printf '          <h3 class="card-title">%s</h3>\n' "$name"
    printf '          <p class="card-desc">%s</p>\n' "$long"
    printf '          <div class="badges"><span class="badge status">%s</span><span class="badge">Installers ready</span><span class="badge">macOS</span><span class="badge">Windows</span><span class="badge">Linux</span><span class="badge">Web</span></div>\n' "$status_label"
    printf '          <span class="launch">Launch %s →</span>\n' "$name"
    printf '        </div>\n'
    printf '      </a>\n'
  done
  cat <<'HTML'
    </div>
  </div>

  <footer>
    Craft Apps web builds, auto-updated from GitHub releases.
    &nbsp;·&nbsp;
    Deployed with
    <a href="https://github.com/liyu1981/deploy-photocraftweb" target="_blank" rel="noopener">github.com/liyu1981/deploy-photocraftweb</a>
  </footer>
  </div>
</body>
</html>
HTML
} > "$INDEX"

# Write version metadata.
printf '%s\n' "${META_LINES[@]}" > "$VERSIONS_FILE.tmp"

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
