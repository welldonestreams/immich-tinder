# Plan: Reviewed-Cache (IDs + Entscheidung) in `localStorage`

## Ziel
- Jede Asset-ID, die bereits **reviewt** wurde, wird persistent gespeichert, damit sie **nicht erneut** angezeigt wird (Fotos **und** Videos).
- Zusätzlich wird die Entscheidung **angenommen/abgelehnt** (intern `keep`/`delete`) ebenfalls persistiert.
- Gilt für beide Modi: **Random** und **Chronologisch**.

## Begriff „reviewt“
- Ein Asset gilt als „reviewt“, sobald der Nutzer eine Entscheidung trifft:
  - `keep` (Swipe rechts / Keep / Add-to-Album / Favorite-Flow der weiter swipt)
  - `delete` (Swipe links / Trash)
- Nur „Anzeigen ohne Entscheidung“ zählt **nicht** als reviewt.

## Datenmodell & Persistence
### Storage-Key (pro Account)
- Pattern (analog `preferences`-Store):
  - `immich-swipe-reviewed:<serverUrl>:<user>`
  - `serverUrl = authStore.serverUrl || 'unknown-server'`
  - `user = authStore.currentUserName || 'default-user'`

### Payload (Version 1)
- Minimal & platzsparend (Arrays, wird zur Laufzeit in Sets gewandelt):
  - `{ "v": 1, "kept": string[], "deleted": string[] }`
- In-Memory:
  - `keptSet`, `deletedSet` für O(1) Lookup
  - Helper: `isReviewed(id)`, `getDecision(id)`, `mark(id, decision)`, `unmark(id)`

### Robustheit / Limits (Entscheidung)
- Optional: „Soft-Limit“ (z.B. max 50k IDs) + FIFO-Pruning, um `localStorage` nicht zu sprengen.
- Parsing-Fehler: Payload verwerfen und neu starten (kein Crash).

## Integration in den Review-Flow
### `src/composables/useImmich.ts`
- Beim **Laden** (Random + Chrono) Assets herausfiltern, die:
  - bereits im Reviewed-Cache sind, oder
  - aktuell als `currentAsset` angezeigt werden (verhindert „next == current“).
- Bei **Keep/Delete/KeepToAlbum/Favorite(→weiter)**:
  - `mark(assetId, keep|delete)` + Persist.
- Bei **Undo**:
  - `unmark(assetId)` + Persist (damit das Asset wieder reviewbar ist).
- Chronologischer Modus:
  - Bisheriges „max 5 attempts“ beim Nachladen reicht nach Reload nicht, wenn schon viele IDs reviewt sind.
  - Anpassung: solange nachladen, bis ein unreviewtes Asset gefunden ist (mit sinnvollem Safety-Limit + Error-Message).

## UI/UX (optional)
- Optionaler Reset-Button (z.B. in Header/Settings): „Reviewed Cache leeren“ (pro Account).
- Nicht nötig für MVP, aber praktisch, wenn man von vorne anfangen will.

## Tests
- Neuer Store-Test:
  - Persist/Rehydrate
  - Namespace-Wechsel (Server/User)
  - mark/unmark + Decision korrekt
- `useImmich`-Test:
  - Random-Flow überspringt reviewed IDs (inkl. „skipVideos“)
  - Undo entfernt Eintrag wieder

## Akzeptanzkriterien
- Ein Asset, das einmal `keep` oder `delete` wurde, taucht auch nach Reload **nicht** wieder auf.
- „Undo“ macht den Cache-Eintrag rückgängig, sodass das Asset wieder erscheint.
- Cache ist pro Server/User getrennt.

## Betroffene Dateien (voraussichtlich)
- `src/stores/…` (neuer Store für Reviewed-Cache)
- `src/composables/useImmich.ts` (Filter + mark/unmark + Chrono-Nachladen)
- `tests/…` (neue Tests)
- Optional: `README.md` (neuer `localStorage` Key dokumentieren)

