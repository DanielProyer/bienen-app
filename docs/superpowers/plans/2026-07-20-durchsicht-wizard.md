# Geführte Durchsicht + Waben-Erfassung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Durchsicht wird ein geführter 3-Schritt-Wizard (Kontext → optional Waben → Kennzahlen) mit großen Touch-Zielen; die optionale Waben-für-Waben-Erfassung befüllt einige Kennzahlen automatisch (überschreibbar, nie bei leeren Waben). Alle bisherigen Felder bleiben erhalten.

**Architecture:** Neue Waben-Domäne (`wabe.dart`, pure) + additives `waben jsonb` an `inspections` (Migration D03, inkl. View-Neubau). Neuer Wizard (`durchsicht_wizard_page.dart`) + controlled `waben_schritt.dart`, ersetzt `durchsicht_form_page.dart`. Gateway/Provider/Tabelle unverändert wiederverwendet.

**Tech Stack:** Flutter Web, Riverpod, Supabase (jsonb-Spalte, View), Dart-Tests. **Spec:** `docs/superpowers/specs/2026-07-20-durchsicht-wizard-design.md` (v2). **Branch:** `feat/durchsicht-wizard`.

**Verifiziert:** Edit-Einstieg = `durchsicht_detail_page.dart:32` (`Navigator.push` mit `bestehend: d`); Route `/voelker/:id/durchsicht` (app_router:410-411); Timeline (`durchsicht_timeline.dart:24/34`) verlinkt nur auf Neu-Route + Detail. View D01: `select distinct on (volk_id) * … order by volk_id, durchgefuehrt_am desc, created_at desc` (security_invoker).

---

## Task 1: Migration D03 — `waben`-Spalte + CHECK + View-Neubau

**Files:** Create `supabase/migrations/D03_inspections_waben.sql`

- [ ] **Step 1: SQL schreiben** (additiv; View **identisch** neu bauen → zieht `waben` mit)
```sql
-- D03_inspections_waben.sql | Waben-Beobachtungen je Durchsicht (geführte Durchsicht, Modul 4.3-Ausbau).
alter table public.inspections add column if not exists waben jsonb;
alter table public.inspections drop constraint if exists inspections_waben_chk;
alter table public.inspections add constraint inspections_waben_chk
  check (waben is null or jsonb_typeof(waben) = 'array');
-- View mit `select *` friert die Spaltenliste zur Erstellzeit ein → waben käme nie mit. Identisch neu bauen:
drop view if exists public.v_letzte_durchsichten;
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) *
  from public.inspections
  order by volk_id, durchgefuehrt_am desc, created_at desc;
-- ROLLBACK: drop constraint inspections_waben_chk; alter table inspections drop column waben;
--   (View bleibt funktionsfähig; bei Bedarf identisch ohne waben neu bauen.)
```

- [ ] **Step 2: Auf Produktion anwenden** (⚠️ FREIGABEPFLICHTIG — nur nach expliziter D03-Zustimmung) via `apply_migration` (name `D03_inspections_waben`).
- [ ] **Step 3: Verifizieren** — `execute_sql`: Spalte `waben` existiert (information_schema.columns); `v_letzte_durchsichten` enthält `waben` (`select column_name from information_schema.columns where table_name='v_letzte_durchsichten'`); Constraint `inspections_waben_chk` da. `get_advisors(security)` → 0 neu.
- [ ] **Step 4: Commit**
```bash
git add supabase/migrations/D03_inspections_waben.sql
git commit -m "feat(durchsicht): Migration D03 inspections.waben + View-Neubau"
```

---

## Task 2: Domain — `wabe.dart` + `durchsicht.dart` (+waben) + Vorbefüllung (pure, TDD)

**Files:** Create `lib/features/durchsicht/domain/wabe.dart`; Modify `lib/features/durchsicht/domain/durchsicht.dart`; Test `test/features/durchsicht/wabe_test.dart`, `test/features/durchsicht/durchsicht_waben_test.dart`

- [ ] **Step 1: Failing tests (`wabe_test.dart`)**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';

void main() {
  test('fromJson/toJson-Roundtrip + Whitelist + Schied-Normalisierung', () {
    final w = WabeBeobachtung.fromJson({'inhalte': ['brut', 'pollen', 'quatsch'], 'koenigin': true, 'stifte': true});
    expect(w.inhalte, {'brut', 'pollen'}); // 'quatsch' gefiltert
    expect(w.koenigin, isTrue);
    expect(w.toJson(), {'inhalte': anyOf(['brut','pollen'], ['pollen','brut']), 'koenigin': true, 'stifte': true});
    // Schied verwirft Inhalte/Flags:
    final s = WabeBeobachtung.fromJson({'schied': true, 'inhalte': ['brut'], 'koenigin': true});
    expect(s.schied, isTrue);
    expect(s.inhalte, isEmpty);
    expect(s.koenigin, isFalse);
    expect(s.toJson(), {'schied': true});
  });

  test('Ableitung: Brutwaben, Königin, Stifte, Futter-Hinweis — Schied zählt nie', () {
    final ws = [
      const WabeBeobachtung(inhalte: {'futter'}),
      const WabeBeobachtung(inhalte: {'brut', 'pollen'}, stifte: true),
      const WabeBeobachtung(inhalte: {'brut'}, koenigin: true),
      const WabeBeobachtung(schied: true),
    ];
    expect(brutWabenAus(ws), 2);
    expect(koeniginAus(ws), isTrue);
    expect(stifteAus(ws), isTrue);
    expect(futterKgHinweisAus(ws), 1 * kFutterKgProWabe); // nur die Futter-Wabe
  });

  test('Schied-Flag leckt nicht (Guard) + leere Liste', () {
    // Ein (theoretisch) Schied mit Flag darf nicht zählen — fromJson normalisiert das ohnehin.
    expect(koeniginAus(const []), isFalse);
    expect(brutWabenAus(const []), 0);
  });

  test('vorbefuellungAus: leere Waben -> null (kein Overwrite); nicht-leer -> Werte', () {
    expect(vorbefuellungAus(const []), isNull);
    final v = vorbefuellungAus([const WabeBeobachtung(inhalte: {'brut'}, koenigin: true)])!;
    expect(v.brutWaben, 1);
    expect(v.koeniginGesehen, isTrue);
    expect(v.stifteGesehen, isFalse);
  });
}
```

- [ ] **Step 2: Test rot.**

- [ ] **Step 3: `wabe.dart` implementieren**
```dart
class WabeBeobachtung {
  final bool schied;
  final Set<String> inhalte;
  final bool koenigin;
  final bool weiselzelle;
  final bool stifte;
  const WabeBeobachtung({this.schied = false, this.inhalte = const {},
      this.koenigin = false, this.weiselzelle = false, this.stifte = false});

  static const kWabenInhalte = <String>{'brut', 'pollen', 'futter', 'honig', 'mittelwand', 'leer', 'baurahmen'};

  factory WabeBeobachtung.fromJson(Map<String, dynamic> j) {
    if ((j['schied'] as bool?) ?? false) return const WabeBeobachtung(schied: true);
    return WabeBeobachtung(
      inhalte: ((j['inhalte'] as List?)?.cast<String>().where(kWabenInhalte.contains).toSet()) ?? const {},
      koenigin: (j['koenigin'] as bool?) ?? false,
      weiselzelle: (j['weiselzelle'] as bool?) ?? false,
      stifte: (j['stifte'] as bool?) ?? false,
    );
  }
  Map<String, dynamic> toJson() => schied
      ? {'schied': true}
      : {
          if (inhalte.isNotEmpty) 'inhalte': inhalte.where(kWabenInhalte.contains).toList(),
          if (koenigin) 'koenigin': true,
          if (weiselzelle) 'weiselzelle': true,
          if (stifte) 'stifte': true,
        };
}

const kFutterKgProWabe = 2.0; // grober Richtwert (Füllgrad ignoriert) — nur Hinweis
bool _istWabe(WabeBeobachtung w) => !w.schied;

int brutWabenAus(List<WabeBeobachtung> ws) => ws.where((w) => _istWabe(w) && w.inhalte.contains('brut')).length;
bool koeniginAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.koenigin);
bool stifteAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.stifte);
num futterKgHinweisAus(List<WabeBeobachtung> ws) =>
    ws.where((w) => _istWabe(w) && (w.inhalte.contains('futter') || w.inhalte.contains('honig'))).length * kFutterKgProWabe;

/// Vorbefüllung der Kennzahlen aus den Waben — null wenn keine Waben (dann KEIN Overwrite).
class WabenVorbefuellung {
  final int brutWaben;
  final bool koeniginGesehen;
  final bool stifteGesehen;
  final num futterKgHinweis;
  const WabenVorbefuellung({required this.brutWaben, required this.koeniginGesehen,
      required this.stifteGesehen, required this.futterKgHinweis});
}
WabenVorbefuellung? vorbefuellungAus(List<WabeBeobachtung> ws) => ws.isEmpty
    ? null
    : WabenVorbefuellung(brutWaben: brutWabenAus(ws), koeniginGesehen: koeniginAus(ws),
        stifteGesehen: stifteAus(ws), futterKgHinweis: futterKgHinweisAus(ws));
```

- [ ] **Step 4: `durchsicht.dart` erweitern** — `import 'wabe.dart';` · Feld `final List<WabeBeobachtung> waben;` (Konstruktor Default `const []`) · fromJson `waben: ((j['waben'] as List?)?.map((e) => WabeBeobachtung.fromJson(e as Map<String, dynamic>)).toList()) ?? const []` · toInsertJson `'waben': waben.isEmpty ? null : waben.map((w) => w.toJson()).toList()`.

- [ ] **Step 5: `durchsicht_waben_test.dart`** — Roundtrip Durchsicht mit waben; **`waben` leer → `toInsertJson()['waben'] == null`**; fromJson ohne `waben` → `[]`.
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';

void main() {
  test('waben leer -> toInsertJson[waben]==null (rückwärtskompatibel)', () {
    final d = Durchsicht(id: '', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 6, 1));
    expect(d.toInsertJson()['waben'], isNull);
  });
  test('waben Roundtrip', () {
    final d = Durchsicht(id: '', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 6, 1),
        waben: const [WabeBeobachtung(inhalte: {'brut'}, koenigin: true)]);
    final j = d.toInsertJson();
    expect((j['waben'] as List).length, 1);
    final back = Durchsicht.fromJson({...j, 'id': 'x'});
    expect(back.waben.single.inhalte, {'brut'});
    expect(back.waben.single.koenigin, isTrue);
  });
  test('fromJson ohne waben -> []', () {
    final d = Durchsicht.fromJson({'id': 'x', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-06-01'});
    expect(d.waben, isEmpty);
  });
}
```

- [ ] **Step 6: Tests grün** (`flutter test test/features/durchsicht`) — inkl. Bestandstests der Durchsicht.
- [ ] **Step 7: Commit**
```bash
git add lib/features/durchsicht/domain/ test/features/durchsicht/wabe_test.dart test/features/durchsicht/durchsicht_waben_test.dart
git commit -m "feat(durchsicht): WabeBeobachtung + Ableitung/Vorbefüllung + Durchsicht.waben (pure)"
```

---

## Task 3: UI — `waben_schritt.dart` (controlled Widget)

**Files:** Create `lib/features/durchsicht/presentation/widgets/waben_schritt.dart`

- [ ] **Step 1: Controlled Widget implementieren** — Input `List<WabeBeobachtung> waben` + `ValueChanged<List<WabeBeobachtung>> onChanged`; die Wizard-Page hält die Wahrheit (Liste + aktive Position + Wabenzahl). Große Ziele (Inhalts-Toggles Grid, Flags, Schied, +/− Wabenzahl, „Nächste/Zurück"), Live-Ableitung unten.
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';

class WabenSchritt extends StatefulWidget {
  final List<WabeBeobachtung> waben;
  final ValueChanged<List<WabeBeobachtung>> onChanged;
  const WabenSchritt({super.key, required this.waben, required this.onChanged});
  @override
  State<WabenSchritt> createState() => _WabenSchrittState();
}

class _WabenSchrittState extends State<WabenSchritt> {
  int _aktiv = 0;

  static const _inhaltLabel = {
    'brut': 'Brut', 'pollen': 'Pollen', 'futter': 'Futter', 'honig': 'Honig',
    'mittelwand': 'Mittelwand', 'leer': 'leer', 'baurahmen': 'Baurahmen',
  };

  List<WabeBeobachtung> get _ws => widget.waben;
  WabeBeobachtung get _w => _ws[_aktiv];

  void _ersetze(WabeBeobachtung neu) {
    final kopie = [..._ws];
    kopie[_aktiv] = neu;
    widget.onChanged(kopie);
  }

  void _toggleInhalt(String key) {
    final set = {..._w.inhalte};
    set.contains(key) ? set.remove(key) : set.add(key);
    _ersetze(WabeBeobachtung(inhalte: set, koenigin: _w.koenigin, weiselzelle: _w.weiselzelle, stifte: _w.stifte));
  }

  void _setSchied(bool on) {
    _ersetze(on ? const WabeBeobachtung(schied: true) : const WabeBeobachtung());
    if (on) {
      // "dahinter Schluss": Positionen nach dem Schied entfernen.
      widget.onChanged(_ws.sublist(0, _aktiv + 1));
      if (_aktiv >= _ws.length - 1) setState(() {});
    }
  }

  void _wabenzahl(int delta) {
    final neu = [..._ws];
    if (delta > 0) {
      neu.add(const WabeBeobachtung());
    } else if (neu.length > 1) {
      neu.removeLast();
      if (_aktiv >= neu.length) _aktiv = neu.length - 1;
    }
    widget.onChanged(neu);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final w = _w;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Waben-Streifen
      Row(children: [
        for (var i = 0; i < _ws.length; i++)
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _aktiv = i),
            child: Container(height: 30, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                border: Border.all(color: i == _aktiv ? AppColors.honeyDark : AppColors.brown300, width: i == _aktiv ? 2 : 0.5),
                color: _ws[i].schied ? AppColors.brown300 : (_ws[i].inhalte.contains('brut') ? AppColors.honey.withAlpha(60) : null))))),
        IconButton(icon: const Icon(Icons.remove), onPressed: () => _wabenzahl(-1)),
        IconButton(icon: const Icon(Icons.add), onPressed: () => _wabenzahl(1)),
      ]),
      const SizedBox(height: 12),
      Text('Wabe ${_aktiv + 1} / ${_ws.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (!w.schied) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _inhaltLabel.entries)
            FilterChip(label: Text(e.value), selected: w.inhalte.contains(e.key),
                onSelected: (_) => _toggleInhalt(e.key)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          FilterChip(avatar: const Icon(Icons.crown, size: 18), label: const Text('Königin'), selected: w.koenigin,
              onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: s, weiselzelle: w.weiselzelle, stifte: w.stifte))),
          FilterChip(label: const Text('Weiselzelle'), selected: w.weiselzelle,
              onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: s, stifte: w.stifte))),
          FilterChip(label: const Text('Stifte'), selected: w.stifte,
              onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: w.weiselzelle, stifte: s))),
        ]),
      ],
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Trennschied (dahinter Schluss)'),
          value: w.schied, onChanged: _setSchied),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(onPressed: _aktiv > 0 ? () => setState(() => _aktiv--) : null, child: const Text('Zurück')),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(
          onPressed: _aktiv < _ws.length - 1 ? () => setState(() => _aktiv++) : null,
          child: const Text('Nächste Wabe →'))),
      ]),
      const SizedBox(height: 12),
      Text('Brutwaben: ${brutWabenAus(_ws)}  ·  Königin: ${koeniginAus(_ws) ? 'ja' : '—'}  ·  Stifte: ${stifteAus(_ws) ? 'ja' : '—'}',
          style: const TextStyle(fontSize: 13, color: AppColors.brown600)),
    ]);
  }
}
```
> Falls `Icons.crown` nicht existiert, ein vorhandenes Icon nehmen (z. B. `Icons.star`). Vor Nutzung prüfen.

- [ ] **Step 2: analyze** — `flutter analyze lib/features/durchsicht/presentation/widgets/waben_schritt.dart` → 0 issues.
- [ ] **Step 3: Commit**
```bash
git add lib/features/durchsicht/presentation/widgets/waben_schritt.dart
git commit -m "feat(durchsicht): waben_schritt (controlled Waben-Erfassung, große Ziele)"
```

---

## Task 4: UI — `durchsicht_wizard_page.dart` (3 Schritte, alle Felder, optional Waben)

**Files:** Create `lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart`

- [ ] **Step 1: Wizard implementieren.** Nimmt `Durchsicht? bestehend` (Objekt-Push, wie das alte Formular). `PageController` mit 3 Seiten; State hält **alle** Felder (aus `durchsicht_form_page.dart` übernehmen: `_datum, _wetter, _temp, _dauer, _weiselzustand, _koeniginGesehen, _stifteGesehen, _weiselzellen(Typ), _wzAnzahl, _brutbild, _brutWaben, _staerke(gassen), _futter, _pollen, _platz, _sanftmut, _wabensitz, _auffaelligkeiten, _massnahmen, _naechste, _fotoPfade, _notiz`) **plus** `List<WabeBeobachtung> _waben = []` und `bool _wabenModus = false`.

**Aufbau (Struktur; Feld-Widgets 1:1 aus `durchsicht_form_page.dart` übernehmen, Number-`TextField`s durch `_TapStepper` ersetzen):**
```dart
// 3 Seiten in einem PageView (oder Stepper). Großer "Weiter"/"Zurück"/"Speichern".
// Seite 1 — Kontext: Datum, Wetter, Temp, Dauer, Weiselzustand-Chips, "Stifte gesehen"-Toggle.
// Seite 2 — Waben (optional):
//   SwitchListTile('Waben einzeln erfassen', _wabenModus) — Default aus.
//   if (_wabenModus) WabenSchritt(waben: _waben.isEmpty ? _startWaben() : _waben, onChanged: (w) => setState(()=>_waben=w))
//   (bei erstem Einschalten _waben mit N leeren Waben initialisieren; N = letzte Durchsicht dieses Volks, sonst 10)
// Seite 3 — Kennzahlen/Abschluss: Brutbild-Chip, Brutwaben(_TapStepper), Gassen(_TapStepper)+Bienen-Schätzung,
//   Futter(_TapStepper) + Hinweistext futterKgHinweisAus wenn Waben, Pollen-Chip, Platz-Chip,
//   Weiselzellen-Typ-Chip + Anzahl(_TapStepper), Königin/Stifte-Toggles, Sanftmut/Wabensitz(1-4 Tap-Buttons),
//   Auffälligkeiten-FilterChips, Maßnahmen, nächste Durchsicht, Foto, Notiz, [Speichern].

// Vorbefüllung: beim Wechsel Seite 2 -> 3 (onPageChanged / "Weiter"), EINMALIG:
void _uebernehmeVorbefuellung() {
  final v = vorbefuellungAus(_waben);        // null wenn keine Waben -> NICHTS überschreiben
  if (v == null || _vorbefuellt) return;
  _brutWaben.text = v.brutWaben.toString();
  _koeniginGesehen = v.koeniginGesehen;
  _stifteGesehen = v.stifteGesehen;
  // futter NICHT auto-setzen — nur als Hinweistext anzeigen.
  _vorbefuellt = true;
}
```
Beim **Bearbeiten** (`bestehend != null`): alle Felder + `_waben = bestehend.waben` laden; wenn `bestehend.waben` nicht leer → `_wabenModus = true`. **Speichern:** baut `Durchsicht(..., waben: _wabenModus ? _waben : const [])` und ruft `durchsichtenFuerVolkProvider(volkId).notifier.speichern(d)` (Muster aus `durchsicht_form_page.dart:81-119`, inkl. Foto-Upload `_fotoAufnehmen`, Rollen-Guard, DurchsichtFehler-Handling).

`_TapStepper` (kleines Widget, große +/−):
```dart
class _TapStepper extends StatelessWidget {
  final String label; final num? wert; final num schritt; final ValueChanged<num?> onCh; final String? hinweis;
  const _TapStepper({required this.label, required this.wert, this.schritt = 1, required this.onCh, this.hinweis});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label), if (hinweis != null) Text(hinweis!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
      IconButton(iconSize: 28, icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onCh(((wert ?? 0) - schritt).clamp(0, 999))),
      SizedBox(width: 40, child: Text('${wert ?? '—'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
      IconButton(iconSize: 28, icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onCh((wert ?? 0) + schritt)),
    ]));
}
```
> **Alle Chips/Slider/Foto/Bienen-Schätzung (`bienenSchaetzung`) exakt aus `durchsicht_form_page.dart` übernehmen** — nur Number-`TextField`s → `_TapStepper`. Kein Feld weglassen (Blocker B1).

- [ ] **Step 2: analyze** — `flutter analyze lib/features/durchsicht` → 0 issues.
- [ ] **Step 3: Commit**
```bash
git add lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart
git commit -m "feat(durchsicht): 3-Schritt-Wizard (alle Felder, optionale Waben, Vorbefüllung)"
```

---

## Task 5: Verdrahtung + altes Formular entfernen

**Files:** Modify `core/router/app_router.dart`, `durchsicht/presentation/pages/durchsicht_detail_page.dart`; Delete `durchsicht/presentation/pages/durchsicht_form_page.dart`

- [ ] **Step 1: Router** — `app_router.dart:36` Import `durchsicht_form_page` → `durchsicht_wizard_page`; Z.410-411 `DurchsichtFormPage(volkId: …)` → `DurchsichtWizardPage(volkId: …)`.
- [ ] **Step 2: Detail-Edit** — `durchsicht_detail_page.dart:6` Import → wizard; Z.32 `DurchsichtFormPage(volkId: volkId, bestehend: d)` → `DurchsichtWizardPage(volkId: volkId, bestehend: d)`.
- [ ] **Step 3: Altes Formular löschen** — `rm lib/features/durchsicht/presentation/pages/durchsicht_form_page.dart` (der Wizard deckt alle Felder ab; keine weiteren Referenzen — Grep bestätigen). Timeline (`durchsicht_timeline.dart`) nutzt nur die Route + Detail → keine Änderung nötig.
- [ ] **Step 4: Grep-Check** — `grep -rn "DurchsichtFormPage\|durchsicht_form_page" lib` → 0 Treffer.
- [ ] **Step 5: analyze + Volltest** — `flutter analyze && flutter test` → 0 issues, alle grün.
- [ ] **Step 6: Commit**
```bash
git add lib/core/router/app_router.dart lib/features/durchsicht/presentation/pages/durchsicht_detail_page.dart
git rm lib/features/durchsicht/presentation/pages/durchsicht_form_page.dart
git commit -m "feat(durchsicht): Wizard verdrahtet (Route + Detail-Edit), altes Formular entfernt"
```

---

## Task 6: Living-Docs + Version-Bump + Deploy

**Files:** Modify `pubspec.yaml`, `docs/decision-log.md`, `docs/roadmap-app.md`, `ToDo.md`; App-Memory

- [ ] **Step 1: Version** → `1.20.0+41`.
- [ ] **Step 2: decision-log** — D-57 (geführter Wizard, alle Felder, optionale Waben, Ableitung nur als überschreibbare Vorbefüllung nie bei leeren Waben; `waben jsonb` + View-Neubau; Gassen/Zellenzahl nicht abgeleitet) + Gotchas (View `select *` friert Spalten ein → Neubau bei Spalten-Add; toInsertJson leer→null; Schied normalisiert).
- [ ] **Step 3: roadmap-app.md** — 4.3 Durchsicht „geführt + Rähmchen" LIVE (v1.20.0); Spracheingabe (Zyklus 2) offen.
- [ ] **Step 4: ToDo.md** — Stand, Erledigtes (Commit-Range), Offenes (Spracheingabe; Waben-Streifen im Detail; Füllgrad-Gewichtung Futter).
- [ ] **Step 5: Deploy** — `bash deploy.sh`; Live-Flip 1.20.0 verifizieren.
- [ ] **Step 6: Commit + Memory**
```bash
git add pubspec.yaml docs/decision-log.md docs/roadmap-app.md ToDo.md
git commit -m "chore(durchsicht): v1.20.0 — Living-Docs + Version-Bump + Deploy"
```
App-Memory: `inspections.waben jsonb` (D03) + Gotcha View-Neubau.

---

## Self-Review (gegen Spec v2)

**1. Spec-Coverage:** §2.1 D03 (waben + CHECK + View-Neubau) → Task 1 ✓ · §2.2 WabeBeobachtung (Whitelist, Schied-Normalisierung, pos→Index) → Task 2 ✓ · §2.3 Ableitung (kein gassenAus/weiselzellenAnzahlAus; _istWabe-Guards) → Task 2 ✓ · §2.4 Durchsicht.waben (leer→null) → Task 2 ✓ · §3 Wizard (3 Schritte, alle Felder, Waben optional, Vorbefüllung nie bei leer) → Task 4 ✓ · waben_schritt controlled → Task 3 ✓ · Verdrahtung + Formular entfernen (Blocker B1) → Task 5 ✓ · §5 Tests → Task 2 ✓ · §6 Deploy → Task 6 ✓.

**2. Placeholder-Scan:** kein TBD. UI-Feld-Widgets in Task 4 verweisen bewusst auf `durchsicht_form_page.dart` als Vorlage (übernehmen, Number→Stepper) — die pure-Logik (Ableitung/Vorbefüllung/Modell) ist voll ausgeschrieben + getestet. `Icons.crown`-Fallback geflaggt.

**3. Typ-Konsistenz:** `WabeBeobachtung`/`vorbefuellungAus`/`WabenVorbefuellung`/`brutWabenAus` konsistent Task 2/3/4. `DurchsichtWizardPage(volkId, bestehend)` konsistent Task 4/5. `_TapStepper`/`WabenSchritt` Task 3/4.

**Offene Plan-Punkte:** `Icons.crown`-Existenz prüfen (sonst `Icons.star`); Waben-Streifen im Detail (nice, optional); Bienen-Schätzung/`kFutterKgProWabe` als Richtwert kommentieren.
