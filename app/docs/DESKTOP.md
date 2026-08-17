# Immich Tinder — Desktop app

Swipe-review your Immich library from a **native desktop app** (Windows, macOS,
Linux). Right = keep, left = delete (to trash), S = skip, F = favorite,
↑/Ctrl+Z = undo.

## Download

Grab the installer for your OS from the
[Releases](https://github.com/welldonestreams/immich-tinder/releases) page:

- **Windows**: `Immich-Tinder-Setup-<ver>.exe` (NSIS installer)
- **macOS**: `Immich-Tinder-<ver>.dmg`
- **Linux**: `Immich-Tinder-<ver>.AppImage`

## First run (setup wizard)

1. Install + launch the app.
2. Enter your **Immich server URL** — e.g. `http://10.0.0.162:30041` (home
   network) or `https://immich.example.com`.
3. Paste your **API key** — in Immich: Account Settings → API Keys → New Key.
   (Create a *scoped* key if your Immich supports it — see SETUP.md for the
   recommended permission list. An admin key works but grants more than the
   app needs.)
4. Hit **Connect** — the app validates the connection (server reachable + key
   valid), then drops you into the swipe view.

Config is stored locally on your machine (browser-style localStorage). Change
it any time from the login screen.

## How it works

The desktop build is the same Vue app wrapped in Electron. Because it runs on
your own machine, it talks to your Immich server **directly** — no reverse
proxy, no CORS workarounds, no key baked into a bundle. Your key never leaves
your computer.

## Development

```bash
npm install
npm run electron:build   # production installers into release/
```

Releases are built automatically by GitHub Actions when a `v*` tag is pushed:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Security notes

- The desktop app **does not** need the nginx proxy — use the web/SETUP.md
  deployment for self-hosted web use.
- Keep your API key private: anyone with it can manage your library.
- The app is a local tool; it never phones home.
