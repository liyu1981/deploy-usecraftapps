# PhotoCraft Web — Vercel deployment

A static, self-hosted copy of the [PhotoCraft](https://github.com/storytold/photocraft)
browser editor, kept up to date from the official GitHub releases and ready to deploy on
[Vercel](https://vercel.com/).

PhotoCraft's web build runs entirely in the browser (WebAssembly), so there is no backend,
database, or build step. Vercel only has to serve the files in `public/`.

## Repository layout

| Path | Purpose |
|---|---|
| `public/` | Generated static site from the upstream web release. Do not edit by hand. |
| `update-photocraft.sh` | Downloads the latest (or a pinned) web release into `public/`. |
| `.photocraft-version` | Release tag, asset name, checksum, and update time last pulled. |
| `vercel.json` | Tells Vercel to serve `public/` and sets the required cache/MIME headers. |

## Update to the latest release

Requirements: `bash`, `curl`, `unzip`, and `sha256sum` (or `shasum`).

```sh
./update-photocraft.sh            # latest upstream release
./update-photocraft.sh v0.15.1    # pin a specific release
```

The script:

1. Resolves the latest release tag from GitHub (or uses the tag you pass).
2. Downloads `photocraft-web-<version>.zip`.
3. Verifies it against the release's `SHA256SUMS.txt`.
4. Atomically replaces `public/` with the extracted site.
5. Writes `.photocraft-version`.

Review and commit the result:

```sh
git add public .photocraft-version
git commit -m "Update PhotoCraft web"
git push
```

## Deploy on Vercel

### Option A — Vercel dashboard (recommended)

1. Push this repository to GitHub/GitLab/Bitbucket.
2. In Vercel, choose **Add New → Project** and import the repository.
3. Configure:
   - **Framework Preset:** Other
   - **Build Command:** leave empty
   - **Output Directory:** `public` (also set in `vercel.json`)
   - **Install Command:** leave empty
4. Click **Deploy**.

Every push to the production branch redeploys automatically. To update PhotoCraft later, run
`./update-photocraft.sh`, commit, and push.

### Option B — Vercel CLI

```sh
npm i -g vercel
vercel          # preview deployment
vercel --prod   # production deployment
```

### Notes

- `vercel.json` sets long-lived immutable caching for hashed assets and `no-cache` for
  `index.html`, `app/photocraft-web.js`, and `app/parts.txt`. Keep those headers if you
  customize the config.
- The site must be served over HTTPS for WebGPU and clipboard access; Vercel provides HTTPS
  automatically. Over plain HTTP the editor falls back to WebGL2.
- No SPA rewrite/fallback is configured on purpose: missing files should return a real 404.
- The upstream release also includes `_headers`, `.htaccess`, `README.md`, and `HOSTING.md`.
  They are copied into `public/` for reference and for portability to other hosts; Vercel
  ignores `_headers` and `.htaccess`.

## Local preview

```sh
python3 -m http.server 8765 --directory public
# open http://localhost:8765/
```

## Upstream

- Source and releases: <https://github.com/storytold/photocraft>
- Web hosting details: `public/HOSTING.md`
- Licenses: `public/LICENSE-MIT`, `public/LICENSE-APACHE`
