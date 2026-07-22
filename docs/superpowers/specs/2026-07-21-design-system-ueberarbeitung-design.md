# App-Design-Überarbeitung — Design-System + Einhandbedienung (Kern-Screens)

**Datum:** 2026-07-21 · **Track:** App · **Status:** Design freigegeben (Abschnitte 1–3), Spec zur Review
**Modell-Strategie:** reine Präsentationsschicht → **Opus 4.8** (Routine-UI); keine DB/RLS/Migration.

---

## 1. Ziel & Kontext

Die App ist funktional weit (26 Module in Arbeit), aber optisch uneinheitlich: Farbe, Abstände und Schriftgrößen werden in jedem Widget **von Hand** gesetzt (`AppColors.brown800`, ad-hoc `Colors.red.shade600`, frei gewählte `EdgeInsets`/`fontSize`). Das erzeugt visuelles Rauschen und Drift zwischen Screens. Gleichzeitig wird die App **am Bienenstand mit einer Hand (Daumen) und Handschuhen** bedient — die heutigen Layouts legen wichtige Aktionen oben rechts (kaum erreichbar).

**Ziel:** ein konsistentes, ruhiges, professionelles Design mit warmer Imkerei-Identität, das **einhändig gut bedienbar** und **einfach** ist. Erster Durchgang = Design-System (Fundament + Bausteine) + die täglich/feldkritischen Kern-Screens; der Rest zieht modulweise nach.

**Nicht-Ziele dieses ersten Durchgangs:** kein Dark-Mode, keine neuen Features, keine DB-/Verhaltensänderung, keine Umstellung aller Screens auf einmal.

### Grundhaltung
- **Mandantenfähig, keine Arosa-Hardcodes** (gilt auch für Beispiel-Texte/Defaults im UI).
- **Rein additiv/ersetzend an der Oberfläche** — Datenflüsse, Provider, Routen bleiben unverändert; nur die Darstellung wird getauscht.

---

## 2. Visuelle Richtung (freigegeben: „A — warm, beruhigt")

Warme Honig-/Bienen-Identität **behalten, aber Farbe herausnehmen**: helle Flächen, viel Weiß, Honig als Akzent, kräftige Farbe **nur als Signal** (Warnung, Status). Ruhige Kopfleisten (hell mit Honig-Unterkante statt dunkelbrauner Balken). Das hält die App unverwechselbar „nach Imkerei", ohne wie Standard-Bürosoftware oder ein Spielzeug zu wirken.

Verworfen: „B — neutral/sachlich" (verliert Charakter), „C — kräftige Identität" (nah am Ist, am wenigsten ruhig).

---

## 3. Design-Tokens (das Fundament, das Konsistenz erzwingt)

Eine zentrale Token-Quelle ersetzt die verstreuten Direktwerte. Bausteine und Screens lesen **nur** Tokens, nie rohe Hex/Pixelwerte.

### 3.1 Farb-Rollen (statt loser Hex)
- **Flächen:** `oberflaeche` (Seiten-Hintergrund, warmes Off-White ~`#FAF7F2`), `karte` (Weiß), `kopfleiste` (Weiß + Honig-Unterkante).
- **Text:** `textPrimaer` (Braun `#4E342E`), `textSekundaer` (`#8B5E0B`/`#A1887F`), `textGedämpft`.
- **Rand:** `rand` (Hairline ~`#EAE3D6`), `randStark`.
- **Akzent:** `honig` (`#D4920B`) — Primäraktion, aktive Nav, ausgewählte Chips.
- **Signal-Rollen** (endlich fester Platz für Rot/Grün/Amber): `erfolg` (Grün — genug/gesund), `warnung` (Amber — nachbestellen/fällig), `gefahr` (Rot — überfällig/Meldepflicht), `info`. Jede Rolle mit Flächen-Tint + Text-Ton als Paar (z. B. Warnung: `#FAEEDA`-Fläche / `#854F0B`-Text).

Die bestehende `AppColors`-Palette bleibt als **Grundpalette** erhalten; die Rollen mappen darauf. Keine ungebundenen `Colors.red.shade*` mehr in Widgets.

### 3.2 Abstände
4/8-Raster: `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`. Kein freies `EdgeInsets` mehr; Bausteine setzen ihr Padding aus Tokens.

### 3.3 Schrift
Feste Skala (Inter, zwei Gewichte 400/500, ruhig): `titel` 20/500, `abschnitt` 16/500, `text` 14–15/400, `label` 12–13/500. Großzügige Zeilenhöhe (~1.35–1.5). Zahlenkolonnen `tabular-nums` (Kosten/Kennzahlen).

### 3.4 Form & Ziele
- Ecken: Karten 12 px, Bedienelemente 12–14 px, Pillen 20 px.
- **Tap-Ziel min. 48 px** (Stepper 52 px) — handschuhtauglich.
- Elevation ruhig: Karten Hairline-Rand + max. sanfte Erhebung, keine Schlagschatten-Orgie.

---

## 4. Einhand-Modell

Optimiert für **Handy hochkant, Daumen, Handschuhe** (das reale Feld-Szenario; Spracheingabe ergänzt bereits).

- **Bodenleiste (`FormScaffold`):** Die Hauptaktion jeder Formular-/Wizard-/Detailseite liegt **unten angeheftet**, groß und Daumen-erreichbar („Weiter"/„Speichern", Honig-gefüllt). „Zurück" daneben (Umriss). Zerstörerisches (Löschen) wandert ins **Overflow (⋯)** oben, nie in die Daumenzone.
- **Kopfleiste = nur Titel + Kontext** (z. B. „Schritt 2/3"). Kein wichtiger Aktionsknopf mehr oben rechts.
- **Große Ziele, wenig Tippen:** ChoiceChips und ±-Stepper (52 px) statt Zahlenfeldern; Sprach-Mikro direkt am Feld. Alles ≥ 48 px.
- **Listen** (Völker/Aufgaben): Hauptaktion als großer schwebender Knopf unten (FAB, z. B. „+ Durchsicht"), Daumen-erreichbar.
- **Bestätigungen** als Bottom-Sheet (`ConfirmSheet`) statt zentralem Dialog — ebenfalls unten erreichbar.

*Abwägung (dokumentiert):* Bodenleiste für „diesen Screen bestätigen" (Formulare/Wizard), FAB für „neu anlegen" (Listen) — bewusst beide, je nach Screen-Zweck, statt „überall nur FAB".

---

## 5. Bausteine (wiederverwendbare Widgets)

Einmal sauber gestaltet, überall gleich. Alle lesen nur Tokens.

| Baustein | Zweck |
|---|---|
| `AppButton` | primär (Honig) / sekundär (Umriss) / text / gefahr — **genau eine Primäraktion pro Screen** |
| `AppCard` | Standard-Karte (Weiß, 12 px, Hairline-Rand, konsistentes Padding) |
| `SectionHeader` | kleines Honig-Label + optionaler Zähler/Aktion |
| `AppListTile` | großes Tap-Ziel: führender Status-Punkt/Icon, Titel + Untertitel, Chevron |
| `StatTile` | Label + große Zahl (tabular-nums) — Cockpit/Kosten |
| `StatusPill` | Signal-Rollen (genug/nachbestellen/überfällig, gesund/krank …) |
| `FormScaffold` | Titel oben, Inhalt scrollt, **Bodenleiste unten** — das Einhand-Gerüst für alle Formulare/Wizards |
| `EmptyState` | freundlicher Leerzustand (Icon + Satz + Aktion) |
| `ConfirmSheet` | Bestätigung als Bodenblatt statt Dialog |

---

## 6. „Einfachheit" konkret (Prinzipien für jeden Screen)

1. **Eine Hierarchie pro Screen** — ein Primärinhalt, der Rest ruhig; weniger Kästen-in-Kästen.
2. **Farbe nur als Signal/Akzent** — ruhige Flächen, das Auge springt sofort aufs Wichtige.
3. **Gleiche Abstände & Größen überall** (Tokens) — weniger Rauschen.
4. **Kurze, aktive Labels** — Verb zuerst, Sentence-case, keine Doppelung.
5. **Selten Genutztes ins Overflow (⋯)** — Hauptscreens zeigen nur das Häufige.

---

## 7. Erster Durchgang & Nachziehen

**Erster Durchgang (dieser Spec/Plan):**
1. **Fundament:** Token-Datei + ausgebautes `ThemeData` (Buttons, Eingaben, Chips, Bottom-Sheet, NavigationBar/Rail); **Inter als lokales Asset** bündeln (statt `google_fonts`-Runtime-Fetch).
2. **Bausteine** (Abschnitt 5) als echte Widgets in `lib/shared/widgets/` (+ ggf. `lib/core/theme/`).
3. **Kern-Screens** neu auf den Bausteinen: **Cockpit** (`dashboard`), **Völker-Liste + Volk-Detail**, **Durchsicht-Wizard** (Referenz fürs Einhand-Muster), **Nav-Leiste** (`app_shell`: „Voelker" → „Völker", aktive Farbe/Icons).

**Nachziehen (spätere, kleine Folge-Durchgänge, je 1 Modul):** Behandlung, Fütterung, Gesundheit, Material, Wissensdatenbank, Vermehrung, Bewertung, Einstellungen, Projekt, Bau, Recherche, Konto. Bis zum jeweiligen Durchgang funktioniert alles unverändert weiter (kein Big-Bang).

---

## 8. Technik & Randbedingungen

- **Reine Präsentationsschicht:** keine Änderung an Providern, Gateways, Routen, DB, RLS. Keine Migration. Modell-Strategie: **Opus 4.8** (Routine-UI).
- **Schrift lokal:** Inter als Asset (pubspec-`fonts:`), `google_fonts`-Abhängigkeit an der Laufzeit entfernen (Offline/erste Anzeige). Falls `google_fonts` sonst nirgends gebraucht wird, Paket später entfernbar.
- **Kein Dark-Mode** (bewusst, YAGNI — Tageslicht-Feldnutzung). Token-Struktur so anlegen, dass ein späterer Dark-Mode nachrüstbar wäre (Rollen statt fixer Hex im Widget).
- **Responsiv:** Bottom-`NavigationBar` (Handy, Daumen) / `NavigationRail` (≥ 800 px, Desktop) bleiben; das Einhand-Muster zielt auf das Handy-Layout.
- **Keine Arosa-Hardcodes** in Beispiel-/Default-Texten.

---

## 9. Tests

- **Bausteine:** schlanke Smoke-Widget-Tests (rendern ohne Absturz, Primär-/Sekundär-Zustände, `FormScaffold` zeigt Bodenleiste). Reine Token-/Hilfsfunktionen (z. B. Rollen-Auflösung) offline testbar.
- **Kern-Screens:** `flutter analyze` sauber + Bestandstests grün (dürfen nicht brechen, da nur Darstellung).
- **Visuelle Abnahme:** im Browser (Boot/Konsole) + **Daniels Feldtest** (eingeloggt, Handy/Handschuh) — die visuelle „professionell/einhändig"-Bewertung ist nutzerseitig.

---

## 10. Offen (spätere Durchgänge)
- Modulweises Nachziehen aller übrigen Screens auf die Bausteine.
- Optionaler Dark-Mode (Rollen sind vorbereitet).
- Feinschliff nach Feldtest (Ziel-Größen, Kontraste, Wortlaut).
