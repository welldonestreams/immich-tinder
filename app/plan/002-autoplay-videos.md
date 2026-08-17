# Plan: Autoplay für Videos (wenn „Skip Videos“ aus ist)

## Ziel
- Wenn `skipVideos === false` (Normalmodus), sollen Assets vom Typ `VIDEO` in der Swipe-Ansicht automatisch abspielen.
- Fotos bleiben unverändert (wie bisher als Preview/Thumbnail).

## Rahmenbedingungen / Constraints
- Autoplay wird von Browsern i.d.R. nur erlaubt, wenn das Video **muted** ist (und auf Mobile zusätzlich `playsinline`).
- Da Immich Requests Auth-Header brauchen (`x-api-key`, optional `X-Target-Host`), kann ein `<video src="...">` nicht direkt mit Headers laden → entweder:
  1) Video per `fetch()` laden und als `blob:` URL an `<video>` hängen (einfach, aber kann bei großen Videos RAM/Time kosten), oder
  2) später eine Streaming-fähige Lösung (z.B. Service Worker / MediaSource) evaluieren.

## Umsetzungsschritte
1. Immich Playback-Endpoint verifizieren
   - Prüfen, welcher Endpoint im aktuellen Immich am besten geeignet ist (z.B. `GET /assets/:id/original` oder dedizierter Playback-Endpoint).
   - Mit `fetch()` inkl. Auth-Headern testen, ob der Response ein Video-MIME-Type liefert und ob die Größe/Performance akzeptabel ist.

2. URL-/Header-Helfer erweitern
   - In `src/composables/useImmich.ts` eine Helper-Funktion ergänzen (z.B. `getAssetOriginalUrl()` oder `getAssetVideoPlaybackUrl()`), analog zu `getAssetThumbnailUrl()`.
   - Weiterhin `getAuthHeaders()` für Video-Requests nutzen (konsistent mit Thumbnail-Loading).

3. `SwipeCard.vue` um Video-Rendering erweitern
   - Wenn `asset.type === 'VIDEO'` und `!uiStore.skipVideos`:
     - `<video>` statt `<img>` rendern.
     - Attribute: `autoplay`, `muted`, `playsinline`; optional `loop` (UX-Entscheidung).
     - Loading-UI beibehalten (Spinner), bis das erste Frame spielbereit ist (`canplay`/`loadeddata`).
   - Video-Download:
     - Video per `fetch(url, { headers: getAuthHeaders(), signal })` laden.
     - `URL.createObjectURL(blob)` als `videoSrc` setzen.
     - Mit `AbortController` laufende Requests bei Asset-Wechsel abbrechen.
   - Cleanup:
     - alte `blob:` URLs bei Asset-Wechsel und `onUnmounted` revoken.
     - Video pausieren, wenn zur nächsten Karte gewechselt wird.

4. Swipe/Interaktion prüfen
   - Sicherstellen, dass Touch/Mouse-Swipe weiterhin zuverlässig funktioniert, auch wenn ein `<video>` im Card-Container liegt.
   - Falls nötig: Pointer-Handling anpassen (z.B. Overlay-Button für Mute/Unmute, aber Swipe weiterhin auf dem Wrapper).

5. Manuelle Verifikation
   - Normalmodus (`skipVideos=false`): Video lädt und startet automatisch (muted), Swipe links/rechts funktioniert.
   - Skip-Modus (`skipVideos=true`): keine Videos werden geladen (wie bisher), keine Regression bei Fotos.
   - Edge-Cases: sehr große Videos, langsame Verbindung, Fehler beim Laden (Fallback: Preview + Fehlermeldung).

## Betroffene Dateien (voraussichtlich)
- `src/components/SwipeCard.vue` (Video-Element, Fetch-Flow, Cleanup)
- `src/composables/useImmich.ts` (Playback-URL Helper, optional)
