# Plan: Docker + GHCR Publish

## Ziel
- Container-Image für `immich-swipe` bauen (Multi-Stage: Node build → Nginx serve).
- GitHub Actions Workflow: Projekt bauen und anschließend das Image nach GitHub Container Registry (GHCR) publishen.

## Schritte
1. Dockerfile prüfen/erstellen (Build-Args für `VITE_*`, Nginx Config kopieren, Port 80).
2. GitHub Actions Workflow anlegen:
   - `npm ci` + `npm run build` (Fail-fast für TS/Vite Build).
   - Docker Build mit Tags/Labels (via `docker/metadata-action`).
   - Login zu `ghcr.io` mit `GITHUB_TOKEN` und Push.
3. Lokal verifizieren: `npm run build` und optional `docker build .`.

## Notes / Security
- Keine Immich API Keys in das veröffentlichte Image backen (würden im Frontend-Bundle landen).
- Konfiguration für Endnutzer: entweder manuelles Login oder eigene Builds mit Build-Args.

