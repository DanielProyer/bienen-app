# Durchsicht-Spracheingabe v2 — sprachgeführter Waben-Durchgang

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** hands-free Wabe-für-Wabe-Erfassung: im Waben-Schritt ein Kommando-Mikro, das mehrere Aktionen pro Satz anwendet („Brut Pollen Königin nächste") und automatisch weiterblättert.

**Architecture:** baut auf der v1-Engine auf (`SpracheErkenner`, `SprachController`, `SprachMikro`, `normalisiere`). Neu: **Mehr-Token-Parser** `parseWabenKommandos` (rein) + **reine Anwendungs-Funktion** `wendeWabenAktionen((liste, aktiv), aktionen) → (liste, aktiv)` — beide offline getestet; der `WabenSchritt` ruft sie nur.

**Tech Stack:** Flutter Web, Riverpod, `dart:js_interop` (v1). Spec: `docs/superpowers/specs/2026-07-20-durchsicht-spracheingabe-design.md` §7. Baut auf v1 (`lib/features/durchsicht/sprache/`).

---

## Dateistruktur

**Geändert:**
- `lib/features/durchsicht/sprache/domain/sprach_kommando.dart` — `WabenAktion`-Typen + `parseWabenKommandos` + `wendeWabenAktionen` anhängen (importiert `wabe.dart`)
- `lib/features/durchsicht/presentation/widgets/waben_schritt.dart` — Kommando-Mikro + `_wendeSprachAktionAn`
- `pubspec.yaml` — Version `1.28.0+50`

**Neu:**
- `test/durchsicht/waben_kommando_test.dart` — Parser + Anwendungs-Funktion

---

## Task 1: `parseWabenKommandos` + `wendeWabenAktionen` (rein, TDD)

**Files:**
- Modify: `lib/features/durchsicht/sprache/domain/sprach_kommando.dart`
- Test: `test/durchsicht/waben_kommando_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  group('parseWabenKommandos', () {
    test('Mehr-Token in Reihenfolge', () {
      final r = parseWabenKommandos('Brut Pollen Königin nächste');
      expect(r.length, 4);
      expect((r[0] as InhaltAktion).key, 'brut');
      expect((r[0] as InhaltAktion).an, isTrue);
      expect((r[1] as InhaltAktion).key, 'pollen');
      expect((r[2] as FlagAktion).flag, 'koenigin');
      expect(r[3], isA<NaechsteAktion>());
    });
    test('Negation', () {
      final r = parseWabenKommandos('kein Brut ohne Königin');
      expect((r[0] as InhaltAktion).an, isFalse);
      expect((r[1] as FlagAktion).an, isFalse);
    });
    test('Navigation, Schied, Dialekt', () {
      expect(parseWabenKommandos('zurück').single, isA<ZurueckAktion>());
      expect(parseWabenKommandos('Trennschied').single, isA<SchiedAktion>());
      expect((parseWabenKommandos('Weisel').single as FlagAktion).flag, 'koenigin'); // Dialekt
    });
    test('unbekannt ignoriert', () => expect(parseWabenKommandos('das ist unklar'), isEmpty));
  });

  group('wendeWabenAktionen', () {
    test('setzt Inhalte + Flags auf aktive Wabe', () {
      final (ws, a) = wendeWabenAktionen(
          [const WabeBeobachtung(), const WabeBeobachtung()], 0,
          [const InhaltAktion('brut', true), const InhaltAktion('pollen', true), const FlagAktion('koenigin', true)]);
      expect(a, 0);
      expect(ws[0].inhalte, {'brut', 'pollen'});
      expect(ws[0].koenigin, isTrue);
    });
    test('Negation entfernt', () {
      final (ws, _) = wendeWabenAktionen([const WabeBeobachtung(inhalte: {'brut'})], 0, [const InhaltAktion('brut', false)]);
      expect(ws[0].inhalte, isEmpty);
    });
    test('nächste am Ende hängt neue Wabe an', () {
      final (ws, a) = wendeWabenAktionen([const WabeBeobachtung()], 0, [const NaechsteAktion()]);
      expect(ws.length, 2);
      expect(a, 1);
    });
    test('zurück am Anfang bleibt', () {
      final (_, a) = wendeWabenAktionen([const WabeBeobachtung()], 0, [const ZurueckAktion()]);
      expect(a, 0);
    });
    test('Schied trunkiert dahinter', () {
      final (ws, a) = wendeWabenAktionen(List.generate(3, (_) => const WabeBeobachtung()), 1, [const SchiedAktion()]);
      expect(ws.length, 2);
      expect(ws[1].schied, isTrue);
      expect(a, 1);
    });
    test('Inhalt auf Schied-Wabe ignoriert', () {
      final (ws, _) = wendeWabenAktionen([const WabeBeobachtung(schied: true)], 0, [const InhaltAktion('brut', true)]);
      expect(ws[0].schied, isTrue);
      expect(ws[0].inhalte, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run → FAIL**

Run: `cd /d/Projekte/Bienen/bienen_app && flutter test test/durchsicht/waben_kommando_test.dart`
Expected: FAIL (Typen/Funktionen fehlen).

- [ ] **Step 3: Implement** (an `sprach_kommando.dart` anhängen; oben `import 'package:bienen_app/features/durchsicht/domain/wabe.dart';` ergänzen)

```dart
// ===== v2: Waben-Durchgang =====
sealed class WabenAktion { const WabenAktion(); }
class InhaltAktion extends WabenAktion { final String key; final bool an; const InhaltAktion(this.key, this.an); }
class FlagAktion extends WabenAktion { final String flag; final bool an; const FlagAktion(this.flag, this.an); }
class SchiedAktion extends WabenAktion { const SchiedAktion(); }
class NaechsteAktion extends WabenAktion { const NaechsteAktion(); }
class ZurueckAktion extends WabenAktion { const ZurueckAktion(); }

// Alias-Keys sind NORMALISIERT (umlaut-gefoldet), weil normalisiere() zuerst läuft.
const _wabenInhaltAlias = <String, String>{
  'brut': 'brut', 'bruet': 'brut',
  'pollen': 'pollen', 'bluetenstaub': 'pollen',
  'futter': 'futter', 'honig': 'honig',
  'mittelwand': 'mittelwand', 'leer': 'leer', 'leere': 'leer',
  'baurahmen': 'baurahmen', 'bauraehmchen': 'baurahmen', 'drohnenrahmen': 'baurahmen',
};
const _wabenFlagAlias = <String, String>{
  'koenigin': 'koenigin', 'chuengin': 'koenigin', 'wysle': 'koenigin', 'weisel': 'koenigin', 'majestaet': 'koenigin',
  'weiselzelle': 'weiselzelle', 'weiselnaepfchen': 'weiselzelle', 'schwarmzelle': 'weiselzelle',
  'stifte': 'stifte', 'stift': 'stifte', 'eier': 'stifte',
};
const _wabenNaechste = {'naechste', 'weiter', 'vor', 'wyter', 'noechschti', 'nechschti'};
const _wabenZurueck = {'zurueck', 'zrugg', 'rueckwaerts'};
const _wabenSchied = {'schied', 'trennschied', 'trenner'};
const _wabenNegation = {'kein', 'keine', 'ohne', 'nicht', 'nein'};

/// Zerlegt einen Satz in Waben-Aktionen. Negation wirkt auf das nächste bekannte Inhalt/Flag-Token.
List<WabenAktion> parseWabenKommandos(String transkript) {
  final out = <WabenAktion>[];
  var neg = false;
  for (final tok in normalisiere(transkript).split(' ')) {
    if (tok.isEmpty) continue;
    if (_wabenNegation.contains(tok)) { neg = true; continue; }
    if (_wabenInhaltAlias.containsKey(tok)) { out.add(InhaltAktion(_wabenInhaltAlias[tok]!, !neg)); neg = false; continue; }
    if (_wabenFlagAlias.containsKey(tok)) { out.add(FlagAktion(_wabenFlagAlias[tok]!, !neg)); neg = false; continue; }
    if (_wabenSchied.contains(tok)) { out.add(const SchiedAktion()); neg = false; continue; }
    if (_wabenNaechste.contains(tok)) { out.add(const NaechsteAktion()); neg = false; continue; }
    if (_wabenZurueck.contains(tok)) { out.add(const ZurueckAktion()); neg = false; continue; }
    // unbekannt: Negation bleibt fürs nächste bekannte Token bestehen (kurze Sätze)
  }
  return out;
}

/// Wendet Aktionen auf (liste, aktiv) an → (neue Liste, neuer Index). REIN. „nächste" am Ende hängt eine leere Wabe an.
(List<WabeBeobachtung>, int) wendeWabenAktionen(List<WabeBeobachtung> liste, int aktiv, List<WabenAktion> aktionen) {
  var ws = [...liste];
  var a = aktiv;
  for (final akt in aktionen) {
    if (ws.isEmpty) break;
    a = a.clamp(0, ws.length - 1);
    final w = ws[a];
    switch (akt) {
      case InhaltAktion(:final key, :final an):
        if (!w.schied) {
          final set = {...w.inhalte};
          an ? set.add(key) : set.remove(key);
          ws[a] = WabeBeobachtung(inhalte: set, koenigin: w.koenigin, weiselzelle: w.weiselzelle, stifte: w.stifte);
        }
      case FlagAktion(:final flag, :final an):
        if (!w.schied) {
          ws[a] = WabeBeobachtung(inhalte: w.inhalte,
              koenigin: flag == 'koenigin' ? an : w.koenigin,
              weiselzelle: flag == 'weiselzelle' ? an : w.weiselzelle,
              stifte: flag == 'stifte' ? an : w.stifte);
        }
      case SchiedAktion():
        ws = ws.sublist(0, a + 1);
        ws[a] = const WabeBeobachtung(schied: true);
      case NaechsteAktion():
        if (a >= ws.length - 1) ws.add(const WabeBeobachtung());
        a++;
      case ZurueckAktion():
        if (a > 0) a--;
    }
  }
  return (ws, a.clamp(0, ws.isEmpty ? 0 : ws.length - 1));
}
```

- [ ] **Step 4: Run → PASS**

Run: `flutter test test/durchsicht/waben_kommando_test.dart`
Expected: PASS. (Rot → Alias-Tabelle/Logik anpassen, nicht die Tests.)

- [ ] **Step 5: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/domain/sprach_kommando.dart test/durchsicht/waben_kommando_test.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): parseWabenKommandos + wendeWabenAktionen (v2, rein)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Kommando-Mikro im Waben-Schritt

**Files:**
- Modify: `lib/features/durchsicht/presentation/widgets/waben_schritt.dart`

- [ ] **Step 1: Imports**

```dart
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';
import 'package:bienen_app/features/durchsicht/sprache/presentation/sprach_mikro.dart';
```

- [ ] **Step 2: Anwendungs-Methode** — in `_WabenSchrittState` ergänzen

```dart
void _wendeSprachAktionAn(List<WabenAktion> aktionen) {
  if (aktionen.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('nicht erkannt'), duration: Duration(milliseconds: 900)));
    return;
  }
  final (liste, aktiv) = wendeWabenAktionen(_ws, _aktiv, aktionen);
  widget.onChanged(liste);
  setState(() => _aktiv = aktiv);
  final w = liste[aktiv];
  final teile = <String>[
    ...w.inhalte.map((k) => _inhaltLabel[k] ?? k),
    if (w.koenigin) 'Königin', if (w.weiselzelle) 'Weiselzelle', if (w.stifte) 'Stifte',
    if (w.schied) 'Schied',
  ];
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Wabe ${aktiv + 1}: ${teile.isEmpty ? '—' : teile.join(', ')}'),
      duration: const Duration(milliseconds: 1100)));
}
```

- [ ] **Step 3: Mikro einsetzen** — als erstes Kind der `Column` in `build()` (vor dem Waben-Streifen-`Row`), damit es über den ganzen Durchgang sichtbar bleibt:

```dart
      SprachMikro(mikroId: 'kmd-waben', label: 'Waben-Kommando sprechen',
          onEndText: (t) => _wendeSprachAktionAn(parseWabenKommandos(t))),
      const SizedBox(height: 8),
```
(Direkt nach `return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [` — der `// Waben-Streifen`-Kommentar + `Row` folgen danach unverändert.)

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/features/durchsicht/`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/presentation/widgets/waben_schritt.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): sprachgeführter Waben-Durchgang im Waben-Schritt (v2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Abschluss — Version, Voll-Check, Deploy

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Version-Bump** — `version: 1.27.0+49` → `version: 1.28.0+50`.

- [ ] **Step 2: Voll-Check**

Run: `cd /d/Projekte/Bienen/bienen_app && flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: alle grün (neu: waben_kommando_test).

- [ ] **Step 3: Deploy**

Run: `bash deploy.sh`
Expected: Build + gh-pages + Live-Flip auf v1.28.0 (bei DNS-Fehler erneut).

- [ ] **Step 4: Commit + Status**

```bash
git -C D:/Projekte/Bienen/bienen_app add pubspec.yaml
git -C D:/Projekte/Bienen/bienen_app commit -m "chore(sprache): v1.28.0 Waben-Durchgang (Spracheingabe v2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git -C D:/Projekte/Bienen/bienen_app status
```

- [ ] **Step 5: Browser-Verifikation (manuell, user-seitig)** — im Waben-Modus (Chrome, Mikro erlauben): Mikro an, „Brut Pollen Königin nächste" → aktive Wabe gesetzt + auf Wabe 2 gesprungen; „kein Pollen", „Trennschied", „zurück" wirken; Quittung „Wabe N: …". (Voice kann nur der Nutzer real testen.)

---

## Self-Review-Notizen
- **Rein & testbar:** sowohl der Parser (`parseWabenKommandos`) als auch die Anwendung (`wendeWabenAktionen`) sind reine Funktionen mit vollständigen Tests → das Widget (Task 2) ist ein dünner Adapter.
- **Konsistenz mit Bestand:** `wendeWabenAktionen` repliziert die Semantik der bestehenden Handbedienung (Schied trunkiert wie `_setSchied`; Inhalte auf Schied-Wabe ignoriert; „nächste" am Ende hängt an, analog `_wabenzahl(+1)`).
- **Additiv:** `SprachMikro` rendert nichts ohne Web Speech → keine Regression; Tippen im Waben-Schritt unverändert.
- **Alias-Keys normalisiert:** alle Alias-Tabellen-Keys sind umlaut-gefoldet, weil `normalisiere()` vor dem Matching läuft (sonst greifen Umlaut-Wörter nie).
