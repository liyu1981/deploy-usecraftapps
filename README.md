# Craft Apps — Vercel deployment

A static, self-hosted copy of the web builds of the [Craft Apps](https://getartcraft.com/apps)
suite (PhotoCraft, VectorCraft, LightCraft, …), kept up to date from the official GitHub
releases and ready to deploy on [Vercel](https://vercel.com/).

Each craft app's web build runs entirely in the browser (WebAssembly), so there is no
backend, database, or build step. Vercel only has to serve the files in `public/`. The
landing page at `/` links to each app under its own subfolder (e.g. `/photocraft/`).

## Repository layout

| Path | Purpose |
|---|---|
| `public/` | Generated static site from the upstream web releases. Do not edit by hand. |
| `crafts.txt` | List of craft apps (slug, display name, description) to deploy. |
| `update-crafts.sh` | Downloads the latest (or a pinned) web release for every app into `public/`. |
| `cron-update.sh` | Pulls, updates, commits, and pushes automatically (for cron). |
| `.craft-versions` | Release tag and checksum last pulled for each app. |
| `vercel.json` | Tells Vercel to serve `public/` and sets the required cache/MIME headers. |
| `dev.sh` | Local preview server (`./dev.sh [port]`, binds 0.0.0.0). |

## Update to the latest releases

Requirements: `bash`, `curl`, `unzip`, and `sha256sum` (or `shasum`).

```sh
./update-crafts.sh                       # latest upstream releases
./update-crafts.sh photocraft v0.16.0    # pin one app to a specific release
```

The script:

1. Resolves the latest release tag for each app from GitHub (or uses the tag you pass).
2. Downloads `<app>-web-<version>.zip`.
3. Verifies it against the release's `SHA256SUMS.txt`.
4. Rebuilds `public/` with one subfolder per app plus a landing page.
5. Writes `.craft-versions`.

Review and commit the result:

```sh
git add public .craft-versions crafts.txt
git commit -m "Update Craft apps web"
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

Every push to the production branch redeploys automatically. To update the Craft apps later,
run `./update-crafts.sh`, commit, and push.

## Automated updates (cron)

`cron-update.sh` pulls `origin`, checks for new Craft releases, commits the result, and
pushes only when something changed. Configure an `origin` remote and git identity first, then
install it with `crontab -e` (adjust the path; this runs daily at 04:00):

```cron
0 4 * * * /home/yli/deploy-photocraftweb/cron-update.sh >> /home/yli/craft-update.log 2>&1
```

Each push triggers a new Vercel deployment automatically.

### Option B — Vercel CLI

```sh
npm i -g vercel
vercel          # preview deployment
vercel --prod   # production deployment
```

### Notes

- `vercel.json` sets long-lived immutable caching for hashed assets and `no-cache` for
  entry files such as `index.html`. Keep those headers if you customize the config.
- The site must be served over HTTPS for WebGPU and clipboard access; Vercel provides HTTPS
  automatically. Over plain HTTP the editors fall back to WebGL2.
- No SPA rewrite/fallback is configured on purpose: missing files should return a real 404.
- The upstream releases also include `_headers`, `.htaccess`, `README.md`, and `HOSTING.md`.
  They are copied into each app's subfolder for reference and portability; Vercel ignores
  `_headers` and `.htaccess`.

## Local preview

```sh
./dev.sh          # serves public/ on http://0.0.0.0:8765/
./dev.sh 8080     # custom port
```

or directly:

```sh
python3 -m http.server 8765 --directory public
```

## Upstream

- Source and releases: <https://github.com/storytold>
- App catalog: <https://getartcraft.com/apps>
- Licenses: `public/<app>/LICENSE-MIT`, `public/<app>/LICENSE-APACHE`