# Plan: Bild/Video darf Action-Buttons nicht aus dem Viewport drücken

## Ziel
- In der Swipe-Ansicht sollen die unteren Action-Buttons (Keep/Delete/Undo) **immer sichtbar** bleiben.
- Media (Bild/Video) soll sich automatisch an den verbleibenden Platz anpassen, ohne zu scrollen (da `html/body/#app` aktuell `overflow: hidden` haben).

## Problem / Ursache (Ist-Zustand)
- Scrolling ist global deaktiviert (`src/style.css` setzt `overflow: hidden` auf `html, body, #app`).
- Wenn die Summe aus Header + Card + Buttons + Instructions > Viewport wird, wird der untere Bereich **geclippt** statt gescrollt.
- In `src/views/HomeView.vue` ist die Card aktuell über `max-h-[70vh]` begrenzt, was die Footer-Höhe (Buttons/Instructions) nicht berücksichtigt und auf kleinen/kurzen Viewports (oder bei Safe-Area) trotzdem Überlauf verursachen kann.
- In flex-Layouts fehlen oft `min-h-0` an Zwischen-Containern, wodurch Kinder nicht sauber “shrink”en und stattdessen overflowen.

## Ansatz
- Die View als echtes “Header / Content (flex-1) / Footer (shrink-0)” Layout aufbauen.
- Dem Content-Bereich explizit erlauben zu schrumpfen (`min-h-0`) und die Card an den verfügbaren Platz binden (`max-h-full` statt `vh`-Hardcode).
- Footer (Buttons + Instructions) als nicht-schrumpfenden Block behandeln und Safe-Area am unteren Rand berücksichtigen.
- Optional (falls nötig): Viewport-Höhe stabilisieren (Mobile Address-Bar) via `100dvh`/border-box statt “min-height” Wachstum.

## Schritte
1. Repro/Diagnose
   - Clipping in kleiner Höhe reproduzieren (z.B. Mobile DevTools, Landscape, iPhone SE).
   - Prüfen, welche Elemente unten aus dem Viewport verschwinden (Buttons vs. Instructions) und bei welchen Breakpoints.

2. Layout in `HomeView.vue` auf “fixed footer” umstellen (ohne `position: fixed`)
   - Root/`main`/Swipe-Wrapper so umbauen, dass der mittlere Bereich exakt den Restplatz bekommt:
     - Zwischencontainer auf `flex flex-col` + `flex-1 min-h-0`.
     - Footer-Block auf `shrink-0` (Buttons + Instructions).
   - Card-Wrapper:
     - `max-h-[70vh]` entfernen oder durch `max-h-full` ersetzen.
     - Card soll innerhalb des Content-Bereichs bleiben (`h-full`/`max-h-full`) und nicht den Footer verdrängen.

3. Card/Media sizing verifizieren (ggf. `SwipeCard.vue` minimal anpassen)
   - Sicherstellen, dass `<img>`/`<video>` im Parent zuverlässig “contain”en:
     - ggf. auf `w-full h-full object-contain` statt nur `max-*` umstellen.
   - Prüfen, ob absolute Overlays (Media-Info) Layout nicht beeinflussen (sollten sie nicht).

4. Safe-Area & Mobile Viewport-Fallen
   - Footer unten um `env(safe-area-inset-bottom)` ergänzen (entweder via bestehendem `.min-h-screen` Mechanismus oder gezielt am Footer).
   - Falls weiterhin Clipping bei dynamischer Address-Bar: Wrapper auf `height: 100dvh` + `box-sizing: border-box` umstellen (z.B. neue Utility-Klasse in `src/style.css` und in Views nutzen).

5. Manuelle Verifikation
   - Verschiedene Gerätehöhen (kurz/hoch), Portrait/Landscape.
   - Desktop + Mobile Breakpoints (Buttons-Layout unterscheidet sich).
   - Extrem-Formate (sehr hohe/weite Bilder, Videos).

## Akzeptanzkriterien
- Action-Buttons sind bei jedem Asset sichtbar, ohne Scroll.
- Media skaliert automatisch (contain) und bleibt innerhalb des verfügbaren Content-Bereichs.
- Keine Regression beim Swipen/Keyboard-Shortcuts.
- Safe-Area unten deckt Notches/Home-Indicator ab (keine überlappenden Buttons).

## Betroffene Dateien (voraussichtlich)
- `src/views/HomeView.vue` (Layout/Flex-Aufteilung, Card-Wrapper Höhe)
- `src/components/SwipeCard.vue` (optional: Media `w-full h-full object-contain`)
- `src/style.css` (optional: Safe-Area/`100dvh` Utility für stabilen Viewport)

