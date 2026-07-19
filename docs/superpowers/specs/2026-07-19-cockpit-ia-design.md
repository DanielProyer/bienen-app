# Cockpit & Informationsarchitektur-Umbau — Design-Spec (v1)

**Datum:** 2026-07-19 · **Status:** freigegeben (Variante A, 4 Tabs) · **Typ:** reine UI-Schicht — **keine DB-Änderung, keine Migration, keine neuen Daten**
**Anlass:** Betrieb läuft seit 2026-07-19 (Volk 1). Tägliche Funktionen müssen mobil mit 1 Klick erreichbar sein; Projekt-/Aufbau-Inhalte (z. T. veraltet: „Start Herbst 2026", Phasenliste) dürfen tiefer liegen und werden aktualisiert.

## 1. Informationsarchitektur (Entscheid: Variante A, Waage-Tab eingespart)

**Bottom-Bar / NavigationRail — 4 Tabs** (mobile-first; 1–2 Reserve-Slots für spätere Betriebs-Tabs bewusst frei):

| # | Tab | Route | Icon | Inhalt |
|---|---|---|---|---|
| 0 | **Cockpit** | `/dashboard` | `home` | Betriebszentrale (§2) |
| 1 | **Völker** | `/voelker` | `hive` | unverändert (Drehscheibe) |
| 2 | **Aufgaben** | `/aufgaben` | `task_alt` | unverändert |
| 3 | **Projekt** | `/projekt` | `folder_open` | neue Sammelseite (§3) |

**Wegfallende Tabs:** Waage (→ Cockpit-Kachel + künftig Volk-Detail via 4.9; Route `/monitoring` bleibt), Material, Bau (→ Projekt-Kacheln; Routen bleiben), Mehr (→ geht in Projekt auf; `mehr_page.dart` wird gelöscht, `/mehr` **redirectet** auf `/projekt` — keine Bookmark-Brüche).

**Tab-Aktivlogik (`_selectedIndex`):** `/voelker*`→1 · `/aufgaben*`→2 · `/projekt*`, `/material*`, `/construction*`, `/monitoring*`, `/recherche*`, `/entscheidungen*`, `/konto*`, `/mehr*`→3 · sonst 0. **Alle bestehenden Routen bleiben gültig** — es ändert sich nur die Erreichbarkeit.

## 2. Cockpit (`/dashboard`, ersetzt das Projekt-Dashboard)

Nach Dringlichkeit gestapelt; **konsumiert ausschliesslich bestehende Provider** (keine neuen Fetches):

1. **Kopfzeile** (schlank): „Cockpit" + Wochentag/Datum. (Korrektur nach Codebase-Check: der Auth-State trägt nur `betriebId`, keinen Betriebsnamen — ein Name-Fetch dafür wäre YAGNI.) Das Konto-Icon in der AppBar bleibt. Der bisherige grosse Header mit **Arosa-Hardcode** („Maiensäss Tannen 85a · 1570 m · Start Herbst 2026") **entfällt ersatzlos** (Mandanten-Regel).
2. **Warnband** (nur wenn nötig, rotes Band je Befund):
   - überfällige Aufgaben (`offeneAufgabenStatsProvider.ueberfaellig > 0`) → Tap `/aufgaben`;
   - aktive meldepflichtige Gesundheitsereignisse: über die aktiven Völker `aktiveMeldepflichtProvider(volkId)` gesammelt (Family-Watch je Volk; bei Zielgrösse ≤ 8 Völker unkritisch) → Tap Volk-Detail.
   - Später (4.9): Waage-Alarme. Kein Befund → kein Band.
3. **Karte „Heute & demnächst":** die nächsten **3 offenen Aufgaben** (überfällige zuerst, dann nach `faellig_am`; reine Ableitung aus `aufgabenListProvider` — kleine pure Funktion `naechsteOffene(alle, stichtag, n)` in `aufgaben/domain/aufgaben_gruppierung.dart`, mit Test). Je Zeile: **Checkbox direkt abhakbar** (bestehender `abhaken`-Notifier, fehlerfest + Undo-Snackbar wie in 4.4), Titel, Volk-Chip, Fälligkeit (überfällig rot). Fusszeile: „✨ N Saisonvorschläge warten" (`vorschlaegeProvider`, nur wenn N>0) + „alle →" → `/aufgaben`. Schreibrechte beachtet (viewer: read-only).
4. **Karte „Völker":** je aktivem Volk eine Zeile (aus `aktiveVoelkerProvider`): Ampel-Punkt (`gesundheitsstatus` laut C04-CHECK: `unauffaellig`=grün, `beobachtung`=amber, `krank`/`sperre`=rot), Name, „gesehen: <relativ>" aus `letzteDurchsichtenProvider` (View `v_letzte_durchsichten`), Meldepflicht-Badge falls aktiv. Tap → `/voelker/:id`. „alle →" → `/voelker`. Leerzustand: „Noch kein Volk erfasst" + Link.
5. **Karte „Waage & Sensorik":** bis 4.9 ein **statischer Platzhalter** („HiveWatch-Stockwaage folgt — danach hier: Gewicht 24 h, Brutraumtemperatur, Alarme"); **Demo-Daten werden bewusst NICHT angezeigt** (ehrlich statt Show). Tap → `/monitoring`. Die Kachel ist der spätere 4.9-Andockpunkt.

**Dateien:** `dashboard_page.dart` wird zum schlanken Kompositum; die vier Blöcke als eigene Widgets unter `lib/features/dashboard/widgets/` (`warnband.dart`, `heute_karte.dart`, `voelker_karte.dart`, `waage_kachel.dart`). Die alten Bausteine (`_buildHeader`, `_buildProjectPhases`, `_buildQuickLinks`, `_buildKeyFacts`) entfallen dort.

## 3. Projekt-Seite (`/projekt`, neu — Nachfolger von „Mehr" + Projekt-Teilen des Dashboards)

1. **Kopfkarte:** „Projekt Imkerei <Betriebsname>" + Status-Zeile „Betrieb läuft seit 19.07.2026" (siehe Meilenstein-Konstante).
2. **Bereichs-Kacheln (2-spaltiges Grid):** Material & Lager (`/material`) · Bau (`/construction`) · Recherche (`/recherche`) · Entscheidungen (`/entscheidungen`) · Monitoring-Verwaltung (`/monitoring`) · Konto & Team (`/konto`). Nur Navigation, keine Logik.
3. **Projektfortschritt (aktualisiert):** Meilenstein-Liste als **Dart-Konstante** `kProjektMeilensteine` (`lib/features/projekt/domain/meilensteine.dart`): ✓ Planung & Recherche (2025/26) · ✓ Bienenstand gebaut (Jul 26) · ✓ Erstausstattung gekauft (Jul 26) · ✓ Volk 1 übernommen (19.07.26) · ➄ HiveWatch-Waage live (~Aug 26, „nächster Schritt"-Markierung) · ○ Einwinterung Volk 1 (Herbst 26) · ○ Volk 2 + 1. Ernte (2027) · ○ 4 Völker → max 8 (2028–30). Gepflegt beim Arbeitsschluss — **kein Datenmodell (YAGNI)**.
4. **KeyFacts** kompakt (aus dem alten Dashboard übernommen, aktualisiert): Dadant Blatt 10er · Buckfast (T. Hassler) · Ziel Bio-Honig, max 8 Völker · Betreiber Daniel & Lorena.

**Mandanten-Hinweis (bewusste Ausnahme, dokumentiert):** Die statischen Projekt-Inhalte (Meilensteine, KeyFacts — wie schon heute Bau-Anleitungen und Recherche-Assets) sind **Mandant-1-Aufbau-Doku**, kein Betriebs-Feature. Bei einer späteren Vermarktung wird der gesamte Projekt-Bereich tenant-spezifisch bzw. per Feature-Flag ausgeblendet — das ist der bestehende, akzeptierte Zustand der statischen Inhalte und wird durch diesen Umbau nicht verschlechtert (im Gegenteil: der Arosa-Header verschwindet aus dem täglichen Cockpit).

**Dateien:** `lib/features/projekt/pages/projekt_page.dart` + `lib/features/projekt/domain/meilensteine.dart` (neu); `lib/features/mehr/` (Ordner) wird **gelöscht**.

## 4. Fehlerbehandlung & Edge Cases

- Cockpit-Karten sind gegenüber ladenden/fehlenden Providern tolerant (`valueOrNull ?? []` bzw. Skeleton/Leerzustand) — das Cockpit darf nie als Ganzes crashen, wenn eine Quelle hakt.
- Abhaken im Cockpit: identische Fehlerfestigkeit wie 4.4 (await → Erfolgs-Snackbar mit Undo, catch → Fehler-Snackbar).
- „gesehen: <relativ>": heute/gestern/vor N Tagen/„noch nie" (pure Helper-Funktion mit Test, DST-sicher via UTC-Tagesdifferenz — Gotcha 14).
- Redirect `/mehr` → `/projekt` via GoRoute `redirect:` (kein Build einer Seite).

## 5. Tests

- `naechsteOffene(alle, stichtag, n)`: überfällige zuerst, dann aufsteigend; erledigte/übersprungene raus; n begrenzt (Test in `test/features/aufgaben/gruppierung_test.dart`).
- Relativ-Datum-Helper („gesehen")-Tests inkl. Grenzen (heute/gestern/„noch nie").
- Meilensteine-Konstante: Invarianten-Mini-Test (genau 1 „nächster Schritt", Reihenfolge erledigt→offen).
- Bestehende Tests bleiben grün (Nav-/Routen-Umbau bricht keine Provider).

## 6. Deploy

Version **1.15.0+33**. Kein DB-Teil → keine Migrations-Freigabe nötig. Deploy via `bash deploy.sh` (stehende Freigabe nach grünen Tests).
