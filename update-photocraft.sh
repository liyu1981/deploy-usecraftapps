#!/usr/bin/env bash
#
# Download the latest PhotoCraft web release from GitHub and replace the static
# site in ./public. Pass a tag to pin a specific release, e.g.:
#
#   ./update-photocraft.sh v0.15.1
#
# The upstream repository is https://github.com/storytold/photocraft
# No build tools are required: the release zip already contains the static site.

set -Eeuo pipefail

REPO="storytold/photocraft"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$ROOT_DIR/public"
VERSION_FILE="$ROOT_DIR/.photocraft-version"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in curl unzip find cp mv rm mkdir grep; do
  command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  log "Looking up the latest PhotoCraft release"
  LATEST_URL="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest")" \
    || die "could not query the latest release (check your network connection)"
  TAG="${LATEST_URL##*/}"
  [[ "$TAG" =~ ^v[0-9] ]] || die "unexpected latest-release URL: $LATEST_URL"
else
  [[ "$TAG" =~ ^v[0-9] ]] || die "release tag must look like v0.15.1 (got: $TAG)"
fi

VERSION="${TAG#v}"
ASSET="photocraft-web-${VERSION}.zip"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/photocraft.XXXXXX")"
STAGE_DIR=""
OLD_DIR=""

cleanup() {
  rm -rf "$TMP_DIR"
  if [[ -n "$STAGE_DIR" ]]; then
    rm -rf "$STAGE_DIR"
  fi
  if [[ -n "$OLD_DIR" && -d "$OLD_DIR" && ! -e "$SITE_DIR" ]]; then
    mv "$OLD_DIR" "$SITE_DIR"
  fi
}
trap cleanup EXIT

log "Downloading $ASSET ($TAG)"
curl -fL --retry 3 --retry-delay 2 --progress-bar \
  -o "$TMP_DIR/$ASSET" "$BASE_URL/$ASSET" \
  || die "download failed: $BASE_URL/$ASSET"

# Verify against the release's SHA256SUMS.txt when available. The checksum is
# a nice guard against truncated or tampered downloads.
if curl -fsSL --retry 3 -o "$TMP_DIR/SHA256SUMS.txt" \
    "$BASE_URL/SHA256SUMS.txt"; then
  CHECKSUM_LINE="$(grep -E "[[:space:]]${ASSET//./\\.}\$" \
    "$TMP_DIR/SHA256SUMS.txt" | head -n 1 || true)"
  if [[ -n "$CHECKSUM_LINE" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      (cd "$TMP_DIR" && printf '%s\n' "$CHECKSUM_LINE" | sha256sum -c -) \
        || die "SHA-256 verification failed for $ASSET"
    elif command -v shasum >/dev/null 2>&1; then
      (cd "$TMP_DIR" && printf '%s\n' "$CHECKSUM_LINE" | shasum -a 256 -c -) \
        || die "SHA-256 verification failed for $ASSET"
    else
      warn "neither sha256sum nor shasum found; skipping checksum verification"
    fi
    SHA256="${CHECKSUM_LINE%% *}"
  else
    warn "no checksum for $ASSET in SHA256SUMS.txt; skipping verification"
    SHA256="unknown"
  fi
else
  warn "SHA256SUMS.txt is not available; skipping checksum verification"
  SHA256="unknown"
fi

log "Extracting release"
mkdir -p "$TMP_DIR/extract"
unzip -q "$TMP_DIR/$ASSET" -d "$TMP_DIR/extract"
SRC_DIR="$(find "$TMP_DIR/extract" -mindepth 1 -maxdepth 1 -type d \
  -name 'photocraft-web-*' -print -quit)"
[[ -n "$SRC_DIR" ]] || die "release zip did not contain a photocraft-web-* folder"
[[ -f "$SRC_DIR/index.html" ]] || die "release is missing index.html"
[[ -f "$SRC_DIR/app/parts.txt" ]] || die "release is missing app/parts.txt"

log "Staging static site"
STAGE_DIR="$(mktemp -d "$ROOT_DIR/.photocraft-stage.XXXXXX")"
cp -a "$SRC_DIR/." "$STAGE_DIR/"

# Replace the previous site in one step with a rollback if the move fails.
if [[ -e "$SITE_DIR" && ! -d "$SITE_DIR" ]]; then
  die "$SITE_DIR exists but is not a directory"
fi
if [[ -d "$SITE_DIR" ]]; then
  OLD_DIR="$(mktemp -d "$ROOT_DIR/.photocraft-old.XXXXXX")"
  rmdir "$OLD_DIR"
  mv "$SITE_DIR" "$OLD_DIR"
fi
if ! mv "$STAGE_DIR" "$SITE_DIR"; then
  if [[ -n "$OLD_DIR" ]]; then
    mv "$OLD_DIR" "$SITE_DIR"
  fi
  die "could not move the new site into $SITE_DIR"
fi
STAGE_DIR=""
if [[ -n "$OLD_DIR" ]]; then
  rm -rf "$OLD_DIR"
fi
OLD_DIR=""

cat > "$VERSION_FILE" <<EOF
tag=$TAG
asset=$ASSET
sha256=$SHA256
updated=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

log "PhotoCraft $TAG is now in public/"
log "Recorded release details in .photocraft-version"
printf '\nNext steps:\n'
printf '  git add public .photocraft-version\n'
printf '  git commit -m "Update PhotoCraft web to %s"\n' "$TAG"
printf '  git push    # Vercel redeploys automatically if the repo is connected\n'
