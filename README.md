# Use Craft Apps: self deploy or host craft web apps

<p align="center">
  <img src="https://raw.githubusercontent.com/liyu1981/deploy-usecraftapps/main/preview-thumbnail.png" alt="Use Craft Apps preview" />
</p>

A static, self-hosted copy of the web builds of the [Craft Apps](https://getartcraft.com/apps)
suite (PhotoCraft, VectorCraft, LightCraft, …), kept up to date from the official GitHub
releases and ready to self host or deploy on cloud (Vercel, Netlify, Cloudflare Pages, …).

Each craft app's web build runs entirely in the browser (WebAssembly), so there is no
backend, database, or build step. Vercel only has to serve the files in `public/`. The
landing page at `/` links to each app under its own subfolder (e.g. `/photocraft/`).

## Contents

- [Self-hosting](#self-hosting)
  - [Host with Apache or nginx](#host-with-apache-or-nginx)
  - [Host with python3 or php](#host-with-python3-or-php)
  - [Host with Docker](#host-with-docker)
- [Self deploy](#self-deploy)
  - [Cloudflare Pages](#cloudflare-pages-recommended-for-free-tier)
  - [Vercel](#vercel)
  - [Netlify](#netlify)
- [Repository layout](#repository-layout)
- [Update to the latest releases](#update-to-the-latest-releases)
- [Automated updates (cron)](#automated-updates-cron)
- [License](#license)
- [Upstream](#upstream)

## Self-hosting

Large binaries are stored with [Git LFS](https://git-lfs.com). After cloning, materialise
them and serve the resulting `public/` folder:

```sh
git clone https://github.com/liyu1981/deploy-usecraftapps.git
cd deploy-usecraftapps
./prepare-public.sh          # pulls LFS objects into public/
```

`public/` is now a complete static site. Point any HTTP server at it.

### Host with Apache or nginx

Use `public/` as the document root. The per-app `.htaccess` files shipped in each
subfolder handle MIME types and caching; make sure `AllowOverride` is enabled:

```apache
<VirtualHost *:80>
    DocumentRoot /path/to/deploy-usecraftapps/public
    <Directory /path/to/deploy-usecraftapps/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

For nginx, serve the folder statically and set the WebAssembly MIME type (nginx may not
include it by default):

```nginx
server {
    listen 80;
    root /path/to/deploy-usecraftapps/public;
    location / {
        try_files $uri $uri/ =404;
    }
    location ~* \.wasm$ {
        types { application/wasm wasm; }
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
}
```

### Host with python3 or php

For a quick local or small self-hosted server:

```sh
./dev.sh          # serves public/ on http://0.0.0.0:8765/
./dev.sh 8080     # custom port
```

or directly:

```sh
python3 -m http.server 8765 --directory public
php -S 0.0.0.0:8765 -t public
```

No build step is required; the site runs entirely in the browser.

### Host with Docker

Materialise the LFS assets first, then build and run the included image:

```sh
./prepare-public.sh
docker build -t use-craft-apps .
docker run --rm -p 8080:80 use-craft-apps
```

Open http://localhost:8080/. The image uses nginx on Alpine and serves `public/`
with the WebAssembly MIME type and sensible cache headers.

To deploy the container elsewhere, push it to a registry and run it on any
container host (Docker Compose, Kubernetes, a VPS, etc.):

```sh
docker tag use-craft-apps registry.example.com/use-craft-apps:latest
docker push registry.example.com/use-craft-apps:latest
```

The container listens on port 80 and needs no environment variables. Put an
HTTPS reverse proxy or load balancer in front of it for WebGPU/clipboard
support.

## Self deploy

### Cloudflare Pages (recommended for free tier)

Use the included `wrangler.toml`:

- **Build command:** `bash prepare-cloudflare.sh`
- **Build output directory:** `workspace/public`
- `prepare-cloudflare.sh` materializes the LFS assets, copies them into the
  gitignored `workspace/public/` folder, splits any `*_bg.wasm` above 20 MB into
  chunks of at most 20 MB, and installs a small client-side bootstrap
  (`stitch-bootstrap.js`). The bootstrap fetches the chunks sequentially and
  stitches them back into one `ArrayBuffer` before `WebAssembly` instantiation.
- This keeps every file under Cloudflare Pages' 25 MB per-file limit, avoids R2
  and Functions, and stays within the free tier with no per-request operation
  caps. Split chunks are immutable (their names carry the WASM content hash);
  manifests and the bootstrap are served with `no-cache`.

#### How the splitting/stitching works

1. **Build time:** oversized `*_bg.wasm` files are split with
   `split -b 20971520` into `foo_bg.wasm.000`, `.001`, … and a
   `foo_bg.wasm.manifest` lists the chunks.
2. **Runtime:** the bootstrap overrides `fetch`; when the app requests
   `foo_bg.wasm`, it fetches the manifest, downloads the chunks sequentially,
   concatenates them, and returns a `Response` with
   `Content-Type: application/wasm`. Existing loaders (`init`,
   `compileStreaming`, custom URL loaders) work unchanged.
3. `photocraft` keeps its native parts scheme, which is already
   Cloudflare-safe.

### Vercel

#### Option A — Vercel dashboard (recommended)

1. Push this repository to GitHub/GitLab/Bitbucket.
2. In Vercel, choose **Add New → Project** and import the repository.
3. Configure:
   - **Framework Preset:** Other
   - **Build Command:** `bash prepare-public.sh` (also set in `vercel.json`)
   - **Output Directory:** `public` (also set in `vercel.json`)
   - **Install Command:** leave empty
4. Click **Deploy**.

`prepare-public.sh` runs during the build and pulls the Git LFS assets (WebAssembly and
large part files) into `public/`, so the deployed site serves the real binaries instead
of LFS pointer files. If you prefer, you can also enable **Git LFS** in the project's
**Settings → Git**; the build command remains a safe fallback that materialises any
remaining pointers.

Every push to the production branch redeploys automatically. To update the Craft apps later,
run `./update-crafts.sh`, commit, and push.

#### Option B — Vercel CLI

The Vercel CLI uploads your local working tree, so materialise the LFS assets first:

```sh
./prepare-public.sh
npm i -g vercel
vercel          # preview deployment
vercel --prod   # production deployment
```

#### Notes

- `vercel.json` sets long-lived immutable caching for hashed assets and `no-cache` for
  entry files such as `index.html`. Keep those headers if you customize the config.
- The site must be served over HTTPS for WebGPU and clipboard access; Vercel provides HTTPS
  automatically. Over plain HTTP the editors fall back to WebGL2.
- No SPA rewrite/fallback is configured on purpose: missing files should return a real 404.
- The upstream releases also include `_headers`, `.htaccess`, `README.md`, and `HOSTING.md`.
  They are copied into each app's subfolder for reference and portability; Vercel ignores
  `_headers` and `.htaccess`.
- **Storage/egress caution:** the site ships large WebAssembly binaries. Reduce the number
  of retained deployments in your Vercel project settings to save deployment storage, and
  monitor bandwidth/egress usage, since each visitor downloads these large assets.

### Netlify

Use the included `netlify.toml`:

- **Build command:** `bash prepare-public.sh`
- **Publish directory:** `public`
- Set `GIT_LFS_ENABLED=true` in the Netlify site settings (it must be set in the UI,
  not only in `netlify.toml`, so it is available before clone). `prepare-public.sh`
  also pulls LFS objects as a fallback.
- **Storage/egress caution:** the site ships large WebAssembly binaries. Reduce retained
  deploy history to save storage and monitor bandwidth/egress usage.

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
| `prepare-public.sh` | Materialise Git LFS assets in `public/` for self-hosting. |

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

## Automated updates (cron)

`cron-update.sh` pulls `origin`, checks for new Craft releases, commits the result, and
pushes only when something changed. Configure an `origin` remote and git identity first, then
install it with `crontab -e` (adjust the path; this runs daily at 04:00):

```cron
0 4 * * * /home/yli/deploy-photocraftweb/cron-update.sh >> /home/yli/craft-update.log 2>&1
```

Each push triggers a new Vercel deployment automatically.

## License

Each Craft app keeps its upstream license; see `public/<app>/LICENSE-MIT` and
`public/<app>/LICENSE-APACHE`. This repository (landing page, scripts, and
configuration) is licensed under the [MIT License](LICENSE).

## Upstream

- Source and releases: <https://github.com/storytold>
- App catalog: <https://getartcraft.com/apps>
- Licenses: `public/<app>/LICENSE-MIT`, `public/<app>/LICENSE-APACHE`
