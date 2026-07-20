# Geführte Waben-Durchsicht (Modul 4.3-Ausbau) — Design-Spec (v1)

**Datum:** 2026-07-20 · **Status:** in Review · **Modul:** 4.3 Durchsicht/Stockkarte (Ausbau) · **Version:** 1.20.0+41
**Anlass:** Das bestehende Durchsicht-Formular (`durchsicht_form_page.dart`) ist ein langes Scroll-Formular mit ~20 Feldern, davon viele **Number-TextFields** (Temperatur, Dauer, Weiselzellen-Anzahl, Brutwaben, Wabengassen, Futter-kg) — mit Handschuhen im Feld mühsam. Zwei Ziele: (1) **Beurteilung der einzelnen Rähmchen/Waben** (bisher nur Volk-Ebene) und (2) **geführte, handschuh-taugliche Eingabe** (große Ziele, kaum Tastatur).

> **Kern-Insight:** Die Waben-Erfassung ist der Hebel gegen das Zahlen-Tippen: geht man Wabe für Wabe durch (1 Tipp je Wabe), lassen sich die Volk-Kennzahlen (Brutwaben, besetzte Gassen, Futter) **automatisch ableiten** statt manuell eingeben.

> **Zerlegung:** **Zyklus 1 (diese Spec) = Geführte Waben-Durchsicht** (Rähmchen-Erfassung + Wizard). **Zyklus 2 (später) = Spracheingabe** (Web Speech API, cross-cutting) — bewusst nicht hier.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Waben-Erfassung je Durchsicht:** Wabe für Wabe die Inhalte antippen (Mehrfach: Brut/Pollen/Futter/Honig/Mittelwand/leer/Baurahmen) + Flags (Königin hier · Weiselzelle) + **Trennschied** als eigener Positions-Typ.
2. **Geführter 3-Schritt-Wizard** (Kontext → Waben → Abschluss) mit großen Touch-Zielen statt langem Formular; ersetzt das Scroll-Formular als Erfassungs-/Bearbeitungs-Weg.
3. **Auto-Ableitung** der Volk-Kennzahlen (`brut_waben`, `staerke_wabengassen`, `futter_kg`, `koenigin_gesehen`, `weiselzellen_anzahl`) aus den Waben — im Abschluss-Schritt **überschreibbar**.
4. **Flexible Beute:** Waben-Anzahl aus dem Volk vorbelegt, per +/− anpassbar (auch <10, Ablegerkasten); Trennschied engt den genutzten Raum ein.
5. **Rückwärtskompatibel:** additives `waben jsonb` an `inspections`; bestehende Durchsichten (`waben = null`) unverändert; Timeline/Detail-Ansicht laufen weiter.

**Nicht-Ziele (spätere Zyklen):** Spracheingabe (Zyklus 2); Brut-Stadien/Verdeckelungsgrad je Wabe (reiche Erfassung); Honigraum-Waben-für-Waben (Honigraum bleibt Volk-Ebene); Mehr-Zargen-Detailansicht als Pflicht (siehe §3, schlank); Offline.

## 2. Datenmodell

### 2.1 Migration M01 (additiv)
```sql
-- M01_inspections_waben.sql | Waben-Beobachtungen je Durchsicht (geführte Waben-Durchsicht).
alter table public.inspections add column if not exists waben jsonb;
-- Keine RLS-/Policy-Änderung (erbt inspections). Kein CHECK auf den JSON-Inhalt — Whitelist wird in Dart erzwungen.
-- ROLLBACK: alter table public.inspections drop column if exists waben;
```

### 2.2 Dart `wabe.dart` (Modell + Whitelist + Ableitung, pure)
```dart
class WabeBeobachtung {
  final int pos;                 // 1-basiert
  final bool schied;             // Trennschied → keine Wabe, keine Inhalte
  final Set<String> inhalte;     // aus kWabenInhalte; leer wenn schied
  final bool koenigin;
  final bool weiselzelle;
  const WabeBeobachtung({required this.pos, this.schied = false,
      this.inhalte = const {}, this.koenigin = false, this.weiselzelle = false});

  static const kWabenInhalte = <String>{'brut', 'pollen', 'futter', 'honig', 'mittelwand', 'leer', 'baurahmen'};

  factory WabeBeobachtung.fromJson(Map<String, dynamic> j) => WabeBeobachtung(
        pos: j['pos'] as int,
        schied: (j['schied'] as bool?) ?? false,
        inhalte: ((j['inhalte'] as List?)?.cast<String>().where(kWabenInhalte.contains).toSet()) ?? const {},
        koenigin: (j['koenigin'] as bool?) ?? false,
        weiselzelle: (j['weiselzelle'] as bool?) ?? false,
      );
  Map<String, dynamic> toJson() => {
        'pos': pos,
        if (schied) 'schied': true,
        if (inhalte.isNotEmpty && !schied) 'inhalte': inhalte.where(kWabenInhalte.contains).toList(),
        if (koenigin) 'koenigin': true,
        if (weiselzelle) 'weiselzelle': true,
      };
}
```
**Positionen hinter einem Schied werden nicht gespeichert** (implizit ungenutzt). Whitelist wie `Durchsicht.auffaelligkeitenWhitelist` (in Dart gefiltert, DB bleibt lenient).

### 2.3 Ableitungs-Funktionen (pure, `wabe.dart`)
```dart
const kFutterKgProWabe = 2.0; // Richtwert Dadant-Wabe, grobe Schätzung
bool _istWabe(WabeBeobachtung w) => !w.schied;
bool _istBelegt(WabeBeobachtung w) => _istWabe(w) && !(w.inhalte.isEmpty || w.inhalte.difference({'leer','mittelwand'}).isEmpty);

int brutWabenAus(List<WabeBeobachtung> ws) => ws.where((w) => _istWabe(w) && w.inhalte.contains('brut')).length;
int gassenAus(List<WabeBeobachtung> ws) => ws.where(_istBelegt).length;
num futterKgAus(List<WabeBeobachtung> ws) =>
    ws.where((w) => _istWabe(w) && (w.inhalte.contains('futter') || w.inhalte.contains('honig'))).length * kFutterKgProWabe;
bool koeniginAus(List<WabeBeobachtung> ws) => ws.any((w) => w.koenigin);
int weiselzellenAnzahlAus(List<WabeBeobachtung> ws) => ws.where((w) => w.weiselzelle).length;
```

### 2.4 `durchsicht.dart` (Modify)
`+ final List<WabeBeobachtung> waben;` (Default `const []`). `fromJson`: `waben: ((j['waben'] as List?)?.map((e) => WabeBeobachtung.fromJson(e as Map<String,dynamic>)).toList()) ?? const []`. `toInsertJson`: `'waben': waben.isEmpty ? null : waben.map((w) => w.toJson()).toList()` (leer → null = rückwärtskompatibel). Die bestehenden Kennzahl-Felder bleiben; der Wizard **befüllt** sie aus den Ableitungen (überschreibbar).

## 3. UX — der 3-Schritt-Wizard
Neue Seite `durchsicht_wizard_page.dart` (ersetzt `durchsicht_form_page` als Route `/voelker/:id/durchsicht`; `?d=<id>` für Bearbeiten). `PageView`/Stepper mit 3 Schritten, großer „Weiter"-Button, oben ein Fortschritts-Indikator (1/3).

- **① Kontext:** Datum (Default heute), Wetter/Temperatur (optional, ein Feld/kompakt), Weiselzustand (Chips). Bewusst knapp.
- **② Waben** (Herzstück, siehe Mockup im Chat): Waben-Streifen oben (farbig nach Inhalt, aktive Wabe hervorgehoben, tippbar zum Springen). Je Position: **Inhalts-Toggles** (Brut/Pollen/Futter/Honig/leer-MW/Baurahmen, Mehrfach, große Buttons) + **Schied**-Button + Flags (Königin hier · Weiselzelle). Großer **„Nächste Wabe →"** + Zurück. **Waben-Anzahl** vorbelegt (aus letzter Durchsicht dieses Volks, sonst 10) + **+/−**. Schied bietet **„dahinter ist Schluss"** (Rest ungenutzt). Unten **live** die abgeleiteten Kennzahlen (Brutwaben/Gassen/Futter/Königin).
- **③ Abschluss:** Sanftmut/Wabensitz (Tap-Buttons 1–4 statt Slider), Auffälligkeiten (FilterChips, wie bisher), Maßnahmen (Text), **abgeleitete Kennzahlen als überschreibbare Felder** (Brutwaben/Gassen/Futter vorbefüllt), nächste Durchsicht (Vorschlag), Foto (Kamera, bestehend). **Speichern** → baut `Durchsicht` mit `waben` + abgeleiteten Spalten, speichert via bestehendem `durchsichtenFuerVolkProvider.speichern`.

**Bearbeiten:** lädt die bestehende Durchsicht inkl. `waben` in den Wizard (bei `waben = null` startet der Waben-Schritt leer/optional — man kann die Durchsicht auch ohne Waben-Ansicht abschließen).
**Detail-Ansicht** (`durchsicht_detail_page`): optional ein **kompakter Waben-Streifen** (read-only) zusätzlich zu den bestehenden Feldern.

## 4. Architektur & Dateien
```
supabase/migrations/M01_inspections_waben.sql
lib/features/durchsicht/domain/wabe.dart                         (neu: WabeBeobachtung, Whitelist, Ableitungs-Funktionen — pure)
lib/features/durchsicht/domain/durchsicht.dart                   (Modify: +waben)
lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart  (neu)
lib/features/durchsicht/presentation/widgets/waben_schritt.dart          (neu: Waben-Schritt, eigenes Widget)
```
**Modify:** `app_router` (Route → Wizard) · Volk-Detailseite (Aktion → Wizard) · optional `durchsicht_detail_page` (Waben-Streifen). Das alte `durchsicht_form_page.dart` wird abgelöst — **im Plan entscheiden:** entfernen (kein Dead Code) oder als „alle Felder"-Fallback belassen. Empfehlung: entfernen, der Wizard deckt alle Felder ab.
**Gateway/Provider/Tabelle:** unverändert wiederverwendet (nur `toInsertJson`/`fromJson` tragen `waben` mit).

## 5. Tests
- **Ableitung (pure):** `brutWabenAus` (Schied + Positionen dahinter zählen nicht); `gassenAus` (leer/MW/Schied ausgeschlossen); `futterKgAus` (Futter+Honig × Richtwert); `koeniginAus`; `weiselzellenAnzahlAus`.
- **WabeBeobachtung:** fromJson/toJson-Roundtrip; **Inhalte-Whitelist** (ungültiger Wert gefiltert); `schied` → keine Inhalte im JSON; `toJson` lässt leere/false-Felder weg (kompakt).
- **Durchsicht:** fromJson/toInsertJson **mit** `waben` (Roundtrip); **`waben` leer → `toInsertJson['waben'] == null`** (rückwärtskompatibel); Bestandstests der Durchsicht bleiben grün.
- Wizard: `flutter analyze` grün; Kern-Logik über die pure-Ableitung getestet.

## 6. Deploy
Version **1.20.0+41** (Minor). Migration M01 auf Produktion `dcdcohktxbhdxnxjvcyp` (freigabepflichtig, kleiner additiver ALTER). `get_advisors(security+performance)` → 0 neue. Kein RPC/Errcode. `bash deploy.sh` nach grünen Tests.

## 7. decision-log / Roadmap
- **D-57 (neu):** Durchsicht als **geführter 3-Schritt-Wizard** mit **Waben-für-Waben-Erfassung** (Multi-Toggle je Wabe + Trennschied), die die Volk-Kennzahlen auto-ableitet → weniger Zahlen-Tippen (handschuh-tauglich). Additives `waben jsonb` (rückwärtskompatibel). Spracheingabe = Zyklus 2.
- **Roadmap:** 4.3 Durchsicht — Ausbau „geführt + Rähmchen" LIVE (v1.20.0).

## 8. Offene Punkte (Plan)
- `durchsicht_form_page.dart` entfernen vs. Fallback — im Plan festlegen (Empfehlung: entfernen).
- Waben-Streifen im Detail-Ansicht: mit (nice) oder erst Zyklus 2 — Plan entscheidet.
- `kFutterKgProWabe`-Richtwert (~2 kg) + „belegte Wabe ≈ Gasse"-Proxy sind grobe Schätzungen (überschreibbar) — im Katalog-Kommentar als Richtwert markieren.
