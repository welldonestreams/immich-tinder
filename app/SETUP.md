# Immich Swipe — setup guide

Swipe-review your Immich library: right = keep, left = delete (to trash),
S = skip, F = favorite, ↑/Ctrl+Z = undo.

This fork adds **Immich v3 API support** (the upstream `assets/random` endpoint
was removed in v3; this uses `POST /search/random`), a **skip** action for
undecided photos, and a **key-in-nginx** deployment model so your API key never
ships in the browser bundle.

Requires **Immich v3.x** (tested on 3.1.0). The upstream
[dev-nick421/immich-swipe](https://github.com/dev-nick421/immich-swipe) targets
older Immich versions — pick accordingly.

## How it works

Single-page app + nginx sidecar. The browser talks to the *same origin*
(`/api/*`), nginx injects your Immich API key and proxies to your server — no
CORS, no key in the client bundle.

## 1. Create a scoped API key in Immich

As an Immich admin, create an API key for this tool (Administration → API keys,
or):

```bash
curl -X POST http://YOUR_IMMICH:2283/api/api-keys \
  -H "x-api-key: $ADMIN_KEY" -H "Content-Type: application/json" \
  -d '{"name":"immich-swipe","permissions":["asset.read","asset.view","asset.update","asset.delete","asset.download","album.read","album.create","album.update","albumAsset.create"]}'
```

Copy the returned `secret` — it is shown only once. (Minimum useful set is
`asset.read/view/update/delete/download`; the album permissions are only needed
for the "add to album" feature.)

## 2. Put the key in nginx (never in the bundle)

Copy `nginx.conf.example` to `nginx.conf` and replace the placeholder with your
key, then keep the file out of git:

```bash
cp nginx.conf.example nginx.conf
# edit: proxy_set_header x-api-key <YOUR_KEY>;
chmod 600 nginx.conf
echo "nginx.conf" >> .gitignore
```

## 3. Configure and build

```bash
cat > .env <<'EOF'
VITE_SERVER_URL=http://YOUR_HOST:2293
VITE_USER_1_NAME=YourName
VITE_USER_1_API_KEY=anything  # the real key is injected by nginx
EOF
docker compose up -d --build
```

Open `http://YOUR_HOST:2293`.

## Security notes

- **Keep it LAN-only.** The tool is designed for your home network. Do not put
  it behind a public hostname — the app is intentionally keyless, but its whole
  threat model assumes the host is trusted.
- **Bind the port to your LAN IP** (e.g. `"10.0.0.x:2293:80"`) if your host is
  reachable from outside.
- **Scope the API key** — never use an admin/"all" key. The permission list
  above is the maximum the tool needs.
- Trash deletes are recoverable for your Immich trash-retention window.

## Multi-user

Add more users in `.env` (`VITE_USER_2_NAME` / `VITE_USER_2_API_KEY`, up to 5);
the app shows a user picker. Each user needs their own scoped key.
