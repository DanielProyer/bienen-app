# Durchsicht-Spracheingabe v1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** hands-free Erfassung im Durchsicht-Wizard per Spracheingabe — v1: Freitext-Diktat (Wetter/Massnahmen/Notiz) + Kommando-Mikro je Formularseite (Kontext + Kennzahlen).

**Architecture:** Austauschbarer `SpracheErkenner` (dünne `dart:js_interop`-Kapsel um die Web Speech API + Fake) hinter einem Dart-Interface; ein **reiner, offline-testbarer Parser** (`parseKommando` + Alias-Tabelle + `deutscheZahl`) wandelt Transkripte in strukturierte Feld-Kommandos; ein `SprachController` (Riverpod) verwaltet das eine aktive Mikro; das `SprachMikro`-Widget ist ein Toggle mit Status/Live-Transkript. Alles rein additiv — Fallback aufs Tippen.

**Tech Stack:** Flutter Web, Web Speech API via `dart:js_interop` (im SDK, keine neue Dependency), Riverpod. Spec: `docs/superpowers/specs/2026-07-20-durchsicht-spracheingabe-design.md`.

**Scope:** NUR v1. Der sprachgeführte Waben-Durchgang (`parseWabenKommandos`) ist ein separater v2-Plan.

---

## Dateistruktur

**Neu:**
- `lib/features/durchsicht/sprache/domain/sprach_kommando.dart` — Kommando-Typen, `parseKommando`, Grammatik/Alias-Tabelle, `deutscheZahl` (REIN)
- `lib/features/durchsicht/sprache/domain/sprache_erkenner.dart` — Interface + `SprachErgebnis`/`ErkennerStatus`/`ErkennerFehler`
- `lib/features/durchsicht/sprache/data/fake_sprache_erkenner.dart` — Test-Double
- `lib/features/durchsicht/sprache/data/web_sprache_erkenner.dart` — `dart:js_interop`-Kapsel
- `lib/features/durchsicht/sprache/data/sprach_controller.dart` — Riverpod-Notifier (aktives Mikro, Status, Interim) + Provider
- `lib/features/durchsicht/sprache/presentation/sprach_mikro.dart` — Toggle-Widget (Diktat- & Kommando-Nutzung über `onEndText`)
- Tests: `test/durchsicht/sprach_kommando_test.dart`, `test/durchsicht/deutsche_zahl_test.dart`, `test/durchsicht/spracheingabe_flow_test.dart`

**Geändert:**
- `lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart` — Diktat-Mikros an Wetter/Massnahmen/Notiz; Kommando-Mikro je Seite → `parseKommando` → State
- `pubspec.yaml` — Version `1.27.0+49` (keine neue Dependency)

---

## Task 1: `deutscheZahl` — Zahl-Parser (Ziffern + Zahlwörter)

**Files:**
- Create: `lib/features/durchsicht/sprache/domain/sprach_kommando.dart`
- Test: `test/durchsicht/deutsche_zahl_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  test('Ziffern', () {
    expect(deutscheZahl('22'), 22);
    expect(deutscheZahl('0'), 0);
    expect(deutscheZahl('3.5'), 3.5);
  });
  test('Zahlwörter 0-99', () {
    expect(deutscheZahl('null'), 0);
    expect(deutscheZahl('drei'), 3);
    expect(deutscheZahl('zwoelf'), 12);
    expect(deutscheZahl('zwanzig'), 20);
    expect(deutscheZahl('zweiundzwanzig'), 22);
    expect(deutscheZahl('einunddreissig'), 31);
  });
  test('kein Treffer', () {
    expect(deutscheZahl('haus'), isNull);
    expect(deutscheZahl(''), isNull);
  });
}
```

- [ ] **Step 2: Run → FAIL**

Run: `cd /d/Projekte/Bienen/bienen_app && flutter test test/durchsicht/deutsche_zahl_test.dart`
Expected: FAIL (Datei/Funktion fehlt).

- [ ] **Step 3: Implement** (Datei anlegen; Kommando-Typen kommen in Task 2 dazu)

```dart
/// Deutsche Zahl aus einem bereits normalisierten Token: Ziffern ODER Zahlwörter 0-99. null = keine Zahl.
num? deutscheZahl(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final z = num.tryParse(t.replaceAll(',', '.'));
  if (z != null) return z;
  const einer = {
    'null': 0, 'eins': 1, 'ein': 1, 'eine': 1, 'zwei': 2, 'drei': 3, 'vier': 4, 'fuenf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9,
  };
  const teens = {
    'zehn': 10, 'elf': 11, 'zwoelf': 12, 'dreizehn': 13, 'vierzehn': 14, 'fuenfzehn': 15,
    'sechzehn': 16, 'siebzehn': 17, 'achtzehn': 18, 'neunzehn': 19,
  };
  const zehner = {
    'zwanzig': 20, 'dreissig': 30, 'vierzig': 40, 'fuenfzig': 50, 'sechzig': 60,
    'siebzig': 70, 'achtzig': 80, 'neunzig': 90,
  };
  if (einer.containsKey(t)) return einer[t];
  if (teens.containsKey(t)) return teens[t];
  if (zehner.containsKey(t)) return zehner[t];
  // Kompositum "<einer>und<zehner>" z.B. zweiundzwanzig
  final i = t.indexOf('und');
  if (i > 0) {
    final e = einer[t.substring(0, i)];
    final z2 = zehner[t.substring(i + 3)];
    if (e != null && z2 != null) return z2 + e;
  }
  return null;
}
```

- [ ] **Step 4: Run → PASS**

Run: `flutter test test/durchsicht/deutsche_zahl_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/domain/sprach_kommando.dart test/durchsicht/deutsche_zahl_test.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): deutscheZahl (Ziffern + Zahlwörter 0-99)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `parseKommando` — Grammatik + Alias-Tabelle

**Files:**
- Modify: `lib/features/durchsicht/sprache/domain/sprach_kommando.dart`
- Test: `test/durchsicht/sprach_kommando_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  SprachKommando? p(String s, [SprachKontext k = SprachKontext.kennzahlen]) => parseKommando(s, k);

  test('Zahl-Kommandos', () {
    expect(p('Brutwaben 5'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'brutwaben').having((z) => z.wert, 'wert', 5));
    expect(p('Wabengassen acht'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'staerke').having((z) => z.wert, 'wert', 8));
    expect(p('Temperatur 22', SprachKontext.kontext), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'temperatur'));
  });
  test('bare Zahl ohne Feldwort → null', () => expect(p('fünf'), isNull));
  test('Enum-Kommandos → technischer Key', () {
    expect(p('Brutbild geschlossen'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'geschlossen'));
    expect(p('Platz zu gross'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'zu_gross'));
    expect(p('Weiselzustand drohnenbrütig', SprachKontext.kontext), isA<EnumKommando>().having((e) => e.wert, 'wert', 'drohnenbruetig'));
  });
  test('Bool + Negation + Mundart', () {
    expect((p('Königin ja') as BoolKommando).wert, isTrue);
    expect((p('keine Königin') as BoolKommando).wert, isFalse);
    expect((p('Chüngin') as BoolKommando).wert, isTrue); // Mundart-Alias
    expect((p('Stifte nein') as BoolKommando).wert, isFalse);
  });
  test('Anzahl Weiselzellen vor Enum Weiselzellen', () {
    expect(p('Anzahl Weiselzellen 3'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'wz_anzahl'));
    expect(p('Weiselzellen schwarmzellen'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'schwarmzellen'));
  });
  test('Auffälligkeit', () {
    expect(p('Auffälligkeit Varroa'), isA<AuffaelligkeitKommando>().having((a) => a.key, 'key', 'varroa_sichtbar'));
  });
  test('Kontext trennt Grammatik', () => expect(p('Brutbild geschlossen', SprachKontext.kontext), isNull));
  test('weisel-Kollision (ganzwortig)', () {
    expect((p('Weisel gesehen') as BoolKommando).feld, 'koenigin');           // Dialekt: Weisel = Königin
    expect(p('Weiselzellen schwarmzellen'), isA<EnumKommando>().having((e) => e.feld, 'feld', 'weiselzellen'));
  });
  test('Zahl vor dem Feldwort', () => expect((p('22 Grad', SprachKontext.kontext) as ZahlKommando).wert, 22));
  test('unbekannt → null', () => expect(p('das Wetter ist schön'), isNull));
}
```

- [ ] **Step 2: Run → FAIL**

Run: `flutter test test/durchsicht/sprach_kommando_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** (an `sprach_kommando.dart` anhängen)

```dart
enum SprachKontext { kontext, kennzahlen, waben }

sealed class SprachKommando {
  const SprachKommando();
}
class ZahlKommando extends SprachKommando { final String feld; final num wert; const ZahlKommando(this.feld, this.wert); }
class EnumKommando extends SprachKommando { final String feld; final String wert; const EnumKommando(this.feld, this.wert); }
class BoolKommando extends SprachKommando { final String feld; final bool wert; const BoolKommando(this.feld, this.wert); }
class AuffaelligkeitKommando extends SprachKommando { final String key; final bool an; const AuffaelligkeitKommando(this.key, this.an); }

/// Normalisiert: lowercase, Umlaut-Folding, Mehrfach-Space → einzeln, trim.
String normalisiere(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

enum _Typ { zahl, boolWert, enumWert }

class _Regel {
  final String feld;
  final List<String> trigger;                 // normalisierte Feldwörter/Aliase (längere zuerst!)
  final _Typ typ;
  final Map<String, List<String>>? enumWerte;  // canonicalKey → normalisierte Wortaliase (nur enum)
  const _Regel(this.feld, this.trigger, this.typ, [this.enumWerte]);
}

const _negation = {'nein', 'kein', 'keine', 'ohne', 'nicht'};

// Reihenfolge zählt: spezifischere/längere Trigger zuerst (z.B. 'anzahl weiselzellen' vor 'weiselzellen').
final Map<SprachKontext, List<_Regel>> _grammatik = {
  SprachKontext.kontext: [
    const _Regel('temperatur', ['temperatur', 'grad'], _Typ.zahl),
    const _Regel('dauer', ['dauer'], _Typ.zahl),
    const _Regel('weiselzustand', ['weiselzustand', 'weisel'], _Typ.enumWert, {
      'weiselrichtig': ['weiselrichtig', 'richtig'],
      'weisellos': ['weisellos', 'los'],
      'drohnenbruetig': ['drohnenbruetig', 'drohnenmuetterchen'],
      'unsicher': ['unsicher'],
    }),
  ],
  SprachKontext.kennzahlen: [
    const _Regel('wz_anzahl', ['anzahl weiselzellen', 'weiselzellen anzahl'], _Typ.zahl),
    const _Regel('brutwaben', ['brutwaben'], _Typ.zahl),
    const _Regel('staerke', ['wabengassen', 'gassen', 'staerke'], _Typ.zahl),
    const _Regel('futter', ['futter'], _Typ.zahl),
    const _Regel('sanftmut', ['sanftmut'], _Typ.zahl),
    const _Regel('wabensitz', ['wabensitz'], _Typ.zahl),
    const _Regel('koenigin', ['koenigin', 'chuengin', 'wysle', 'weisel', 'majestaet'], _Typ.boolWert),
    const _Regel('stifte', ['stifte', 'stift', 'eier'], _Typ.boolWert),
    const _Regel('weiselzellen', ['weiselzellen'], _Typ.enumWert, {
      'keine': ['keine'],
      'spielnaepfchen': ['spielnaepfchen', 'napf', 'naepfchen'],
      'schwarmzellen': ['schwarmzellen', 'schwarm'],
      'nachschaffungszellen': ['nachschaffungszellen', 'nachschaffung'],
    }),
    const _Regel('brutbild', ['brutbild', 'brut'], _Typ.enumWert, {
      'geschlossen': ['geschlossen', 'lueckenlos'],
      'lueckig': ['lueckig', 'loechrig'],
      'bunt': ['bunt'],
      'kaum': ['kaum'],
      'kein': ['kein'],
    }),
    const _Regel('pollen', ['pollen'], _Typ.enumWert, {
      'viel': ['viel'], 'mittel': ['mittel'], 'wenig': ['wenig'], 'kein': ['kein'],
    }),
    const _Regel('platz', ['platz'], _Typ.enumWert, {
      'ok': ['ok', 'okay', 'passt'],
      'eng': ['eng'],
      'honigraum_noetig': ['honigraum', 'honigraum noetig'],
      'zu_gross': ['zu gross', 'gross'],
    }),
  ],
  SprachKontext.waben: const [], // v2
};

// Auffälligkeiten (kontextfrei auf der Kennzahlen-Seite): Trigger 'auffaelligkeit <wort>' oder direkt das Wort.
const _auffaelligkeitAlias = <String, String>{
  'kalkbrut': 'kalkbrut', 'sackbrut': 'sackbrut',
  'faulbrut': 'faulbrut_verdacht', 'amerikanische faulbrut': 'faulbrut_verdacht',
  'sauerbrut': 'sauerbrut_verdacht',
  'ruhr': 'ruhr', 'durchfall': 'ruhr',
  'raeuberei': 'raeuberei', 'wachsmotte': 'wachsmotte',
  'varroa': 'varroa_sichtbar', 'milben': 'varroa_sichtbar',
  'kahlflug': 'kahlflug',
};

/// Ganzwortiges (space-begrenztes) Matching — verhindert Substring-Kollisionen (weisel ⊄ weiselzellen, brut ⊄ brutwaben).
bool _wort(String q, String t) => (' $q ').contains(' $t ');

SprachKommando? parseKommando(String transkript, SprachKontext kontext) {
  final q = normalisiere(transkript);
  if (q.isEmpty) return null;

  if (kontext == SprachKontext.kennzahlen) {
    for (final e in _auffaelligkeitAlias.entries) {
      if (_wort(q, e.key)) return AuffaelligkeitKommando(e.value, !_negation.any((n) => _wort(q, n)));
    }
  }

  for (final regel in _grammatik[kontext] ?? const <_Regel>[]) {
    if (!regel.trigger.any((t) => _wort(q, t))) continue;
    switch (regel.typ) {
      case _Typ.zahl:
        for (final tok in q.split(' ')) {   // Zahl irgendwo im Satz ("Temperatur 22" ODER "22 Grad")
          final n = deutscheZahl(tok);
          if (n != null) return ZahlKommando(regel.feld, n);
        }
        continue; // Feldwort ohne Zahl → nächste Regel probieren
      case _Typ.boolWert:
        return BoolKommando(regel.feld, !_negation.any((n) => _wort(q, n)));
      case _Typ.enumWert:
        for (final ew in regel.enumWerte!.entries) {
          if (ew.value.any((w) => _wort(q, w))) return EnumKommando(regel.feld, ew.key);
        }
        continue; // Feldwort ohne gültigen Wert → weiter
    }
  }
  return null;
}
```

- [ ] **Step 4: Run → PASS**

Run: `flutter test test/durchsicht/sprach_kommando_test.dart`
Expected: PASS. (Falls ein Alias-Test rot ist: die betroffene Zeile in `_grammatik`/`_auffaelligkeitAlias` anpassen, nicht den Test.)

- [ ] **Step 5: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/domain/sprach_kommando.dart test/durchsicht/sprach_kommando_test.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): parseKommando + Grammatik/Alias-Tabelle (v1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Erkenner-Interface + Fake

**Files:**
- Create: `lib/features/durchsicht/sprache/domain/sprache_erkenner.dart`
- Create: `lib/features/durchsicht/sprache/data/fake_sprache_erkenner.dart`

- [ ] **Step 1: Interface + Modelle**

```dart
// sprache_erkenner.dart
abstract class SpracheErkenner {
  bool get verfuegbar;
  Stream<SprachErgebnis> get ergebnisse;
  Stream<ErkennerStatus> get status;
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true});
  Future<void> stoppen();
  void dispose();
}
class SprachErgebnis {
  final String text;
  final bool endgueltig;
  const SprachErgebnis(this.text, {required this.endgueltig});
}
enum ErkennerStatus { idle, hoert, fehler }
enum ErkennerFehler { nichtVerfuegbar, keinMikro, keinNetz, abgebrochen }
```

- [ ] **Step 2: Fake**

```dart
// fake_sprache_erkenner.dart
import 'dart:async';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

class FakeSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  @override
  bool verfuegbar = true;
  @override
  Stream<SprachErgebnis> get ergebnisse => _erg.stream;
  @override
  Stream<ErkennerStatus> get status => _st.stream;
  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async => _st.add(ErkennerStatus.hoert);
  @override
  Future<void> stoppen() async => _st.add(ErkennerStatus.idle);
  @override
  void dispose() { _erg.close(); _st.close(); }
  /// Test-Helfer: simuliert ein Erkennungs-Ergebnis.
  void sende(String text, {bool endgueltig = true}) => _erg.add(SprachErgebnis(text, endgueltig: endgueltig));
}
```

- [ ] **Step 3: Analyze & Commit**

Run: `flutter analyze lib/features/durchsicht/sprache/domain/sprache_erkenner.dart lib/features/durchsicht/sprache/data/fake_sprache_erkenner.dart`
Expected: No issues.
```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/domain/sprache_erkenner.dart lib/features/durchsicht/sprache/data/fake_sprache_erkenner.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): SpracheErkenner-Interface + Fake

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Web-Kapsel (dart:js_interop um Web Speech API)

**Files:**
- Create: `lib/features/durchsicht/sprache/data/web_sprache_erkenner.dart`

> Browser-only, **nicht** unit-getestet (dünne I/O-Kapsel). Ziel: `flutter analyze` sauber + später manuell in Chrome verifiziert (Task 9). Erste `dart:js_interop`-Nutzung im Projekt.

- [ ] **Step 1: Implement**

```dart
import 'dart:async';
import 'dart:js_interop';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

@JS('SpeechRecognition')
external JSFunction? get _ctorStd;
@JS('webkitSpeechRecognition')
external JSFunction? get _ctorWebkit;

extension type _Recognition._(JSObject o) implements JSObject {
  external set continuous(bool v);
  external set interimResults(bool v);
  external set lang(String v);
  external set onresult(JSFunction f);
  external set onerror(JSFunction f);
  external set onend(JSFunction f);
  external void start();
  external void stop();
  external void abort();
}

class WebSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  _Recognition? _rec;
  bool _aktiv = false;
  late final bool _verfuegbar = (_ctorStd ?? _ctorWebkit) != null;

  @override
  bool get verfuegbar => _verfuegbar;
  @override
  Stream<SprachErgebnis> get ergebnisse => _erg.stream;
  @override
  Stream<ErkennerStatus> get status => _st.stream;

  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async {
    if (!_verfuegbar) { _st.add(ErkennerStatus.fehler); return; }
    final ctor = _ctorStd ?? _ctorWebkit;
    final rec = ctor!.callAsConstructor<_Recognition>();
    rec.continuous = kontinuierlich;
    rec.interimResults = true;
    rec.lang = sprache;
    rec.onresult = ((JSObject ev) {
      final results = ev.getProperty('results'.toJS) as JSObject;
      final len = (results.getProperty('length'.toJS) as JSNumber).toDartInt;
      for (var i = 0; i < len; i++) {
        final res = results.getProperty(i.toString().toJS) as JSObject;
        final isFinal = (res.getProperty('isFinal'.toJS) as JSBoolean).toDart;
        final alt = res.getProperty('0'.toJS) as JSObject;
        final text = (alt.getProperty('transcript'.toJS) as JSString).toDart;
        _erg.add(SprachErgebnis(text, endgueltig: isFinal));
      }
    }).toJS;
    rec.onerror = ((JSObject ev) {
      final code = (ev.getProperty('error'.toJS) as JSString?)?.toDart ?? '';
      if (code != 'no-speech' && code != 'aborted') _st.add(ErkennerStatus.fehler);
    }).toJS;
    rec.onend = ((JSObject _) {
      if (_aktiv) { rec.start(); } else { _st.add(ErkennerStatus.idle); }  // nahtloser Dauer-Modus
    }).toJS;
    _rec = rec;
    _aktiv = true;
    rec.start();
    _st.add(ErkennerStatus.hoert);
  }

  @override
  Future<void> stoppen() async {
    _aktiv = false;
    _rec?.stop();
    _st.add(ErkennerStatus.idle);
  }

  @override
  void dispose() { _aktiv = false; _rec?.abort(); _erg.close(); _st.close(); }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/durchsicht/sprache/data/web_sprache_erkenner.dart`
Expected: No issues. (Falls die js_interop-Zugriffe Analyzer-Fehler werfen: die `getProperty`-Aufrufe auf die im installierten SDK gültige `dart:js_interop`-API anpassen — Semantik unverändert. Interop-Feinschliff ist erlaubt, die öffentliche `SpracheErkenner`-Schnittstelle bleibt gleich.)

- [ ] **Step 3: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/data/web_sprache_erkenner.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): Web-Kapsel (dart:js_interop um Web Speech API)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: SprachController (aktives Mikro, Status, Interim) + Provider

**Files:**
- Create: `lib/features/durchsicht/sprache/data/sprach_controller.dart`

> Garantiert **genau ein aktives Mikro**: startet der Nutzer ein zweites, wird das erste gestoppt. Routet End-Transkripte an den Callback des aktiven Mikros.

- [ ] **Step 1: Implement**

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/web_sprache_erkenner.dart';

final spracheErkennerProvider = Provider<SpracheErkenner>((ref) {
  final e = WebSpracheErkenner();
  ref.onDispose(e.dispose);
  return e;
});

class SprachZustand {
  final String? aktivesMikro;   // null = kein Mikro aktiv
  final ErkennerStatus status;
  final String interim;         // Live-Teiltranskript
  const SprachZustand({this.aktivesMikro, this.status = ErkennerStatus.idle, this.interim = ''});
  SprachZustand kopie({String? aktivesMikro = _keep, ErkennerStatus? status, String? interim}) => SprachZustand(
        aktivesMikro: aktivesMikro == _keep ? this.aktivesMikro : aktivesMikro,
        status: status ?? this.status, interim: interim ?? this.interim);
  static const _keep = '__keep__';
}

final sprachControllerProvider = NotifierProvider<SprachController, SprachZustand>(SprachController.new);

class SprachController extends Notifier<SprachZustand> {
  SpracheErkenner get _e => ref.read(spracheErkennerProvider);
  StreamSubscription? _subErg, _subSt;
  void Function(String endText)? _onEnd;

  @override
  SprachZustand build() {
    ref.onDispose(() { _subErg?.cancel(); _subSt?.cancel(); });
    return const SprachZustand();
  }

  bool get verfuegbar => _e.verfuegbar;

  /// Startet [mikroId]; ein bereits aktives anderes Mikro wird gestoppt.
  Future<void> starten(String mikroId, void Function(String endText) onEndText) async {
    if (!_e.verfuegbar) { state = state.kopie(status: ErkennerStatus.fehler); return; }
    _onEnd = onEndText;
    _subErg ??= _e.ergebnisse.listen((r) {
      if (r.endgueltig) { _onEnd?.call(r.text); state = state.kopie(interim: ''); }
      else { state = state.kopie(interim: r.text); }
    });
    _subSt ??= _e.status.listen((s) => state = state.kopie(status: s));
    await _e.starten();
    state = state.kopie(aktivesMikro: mikroId, status: ErkennerStatus.hoert, interim: '');
  }

  Future<void> stoppen() async {
    _onEnd = null;
    await _e.stoppen();
    state = state.kopie(aktivesMikro: null, status: ErkennerStatus.idle, interim: '');
  }
}
```

- [ ] **Step 2: Analyze & Commit**

Run: `flutter analyze lib/features/durchsicht/sprache/data/sprach_controller.dart`
Expected: No issues.
```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/data/sprach_controller.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): SprachController (ein aktives Mikro, Interim-Status)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: `SprachMikro`-Widget (Toggle + Status + Live-Transkript)

**Files:**
- Create: `lib/features/durchsicht/sprache/presentation/sprach_mikro.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

/// Toggle-Mikro. [onEndText] bekommt jedes End-Transkript (Diktat: anhängen; Kommando: parsen).
class SprachMikro extends ConsumerWidget {
  final String mikroId;
  final void Function(String endText) onEndText;
  final String label;
  final bool kompakt; // Diktat = kompakt (nur Icon), Kommando = mit Label/Status
  const SprachMikro({super.key, required this.mikroId, required this.onEndText, this.label = 'Sprechen', this.kompakt = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(sprachControllerProvider.notifier);
    if (!ctrl.verfuegbar) return const SizedBox.shrink(); // Firefox/Safari: kein Mikro
    final z = ref.watch(sprachControllerProvider);
    final aktiv = z.aktivesMikro == mikroId;
    final fehler = aktiv && z.status == ErkennerStatus.fehler;

    void toggle() => aktiv ? ctrl.stoppen() : ctrl.starten(mikroId, onEndText);

    if (kompakt) {
      return IconButton(
        icon: Icon(aktiv ? Icons.mic : Icons.mic_none, color: aktiv ? Colors.red : null),
        tooltip: aktiv ? 'Diktat stoppen' : 'Diktieren',
        onPressed: toggle,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FilledButton.tonalIcon(
        onPressed: toggle,
        icon: Icon(aktiv ? Icons.stop_circle : Icons.mic),
        label: Text(aktiv ? 'hört zu … (tippen zum Stoppen)' : label),
        style: aktiv ? FilledButton.styleFrom(backgroundColor: Colors.red.shade100) : null,
      ),
      if (aktiv && z.interim.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text('„${z.interim}…"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
      if (fehler)
        const Padding(padding: EdgeInsets.only(top: 4, left: 4), child: Text('Kein Netz / Mikro — Spracheingabe pausiert (Tippen geht).', style: TextStyle(fontSize: 12, color: Colors.red))),
    ]);
  }
}
```

- [ ] **Step 2: Analyze & Commit**

Run: `flutter analyze lib/features/durchsicht/sprache/presentation/sprach_mikro.dart`
Expected: No issues.
```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/sprache/presentation/sprach_mikro.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): SprachMikro-Widget (Toggle + Status + Live-Transkript)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Verdrahtung im Wizard (Diktat + Kommando-Mikro je Seite)

**Files:**
- Modify: `lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart`

- [ ] **Step 1: Imports**

```dart
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';
import 'package:bienen_app/features/durchsicht/sprache/presentation/sprach_mikro.dart';
```

- [ ] **Step 2: Kommando-Anwendung** — Methode in `_DurchsichtWizardPageState` ergänzen

```dart
void _wendeKommandoAn(SprachKommando? k) {
  if (k == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('nicht erkannt'), duration: Duration(milliseconds: 900)));
    return;
  }
  String quittung = '';
  setState(() {
    switch (k) {
      case ZahlKommando(:final feld, :final wert):
        switch (feld) {
          case 'temperatur': _temp = wert; case 'dauer': _dauer = wert;
          case 'wz_anzahl': _wzAnzahl = wert; case 'brutwaben': _brutWaben = wert;
          case 'staerke': _staerke = wert; case 'futter': _futter = wert;
          case 'sanftmut': _sanftmut = wert.toInt().clamp(0, 4);
          case 'wabensitz': _wabensitz = wert.toInt().clamp(0, 4);
        }
        quittung = '$feld → $wert';
      case EnumKommando(:final feld, :final wert):
        switch (feld) {
          case 'weiselzustand': _weiselzustand = wert; case 'weiselzellen': _weiselzellen = wert;
          case 'brutbild': _brutbild = wert; case 'pollen': _pollen = wert; case 'platz': _platz = wert;
        }
        quittung = '$feld → $wert';
      case BoolKommando(:final feld, :final wert):
        if (feld == 'koenigin') _koeniginGesehen = wert;
        if (feld == 'stifte') _stifteGesehen = wert;
        quittung = '$feld → ${wert ? 'ja' : 'nein'}';
      case AuffaelligkeitKommando(:final key, :final an):
        an ? _auffaelligkeiten.add(key) : _auffaelligkeiten.remove(key);
        quittung = 'Auffälligkeit $key';
    }
  });
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(quittung), duration: const Duration(milliseconds: 900)));
}
```

- [ ] **Step 3: Kommando-Mikro je Seite** — in `_seiteKontext()` und `_seiteKennzahlen()` als erstes ListView-Kind

`_seiteKontext()` — vor dem `_datumTile('Datum', …)`:
```dart
        SprachMikro(mikroId: 'kmd-kontext', label: 'Kommando sprechen',
            onEndText: (t) => _wendeKommandoAn(parseKommando(t, SprachKontext.kontext))),
        const Divider(),
```
`_seiteKennzahlen()` — als erstes Kind vor dem Königin-SwitchTile:
```dart
      SprachMikro(mikroId: 'kmd-kennzahlen', label: 'Kommando sprechen',
          onEndText: (t) => _wendeKommandoAn(parseKommando(t, SprachKontext.kennzahlen))),
      const Divider(),
```

- [ ] **Step 4: Diktat-Mikros an den 3 Textfeldern** — das jeweilige `TextField` in eine `Row` mit kompaktem `SprachMikro` packen, das den Text anhängt:

Wetter (in `_seiteKontext()`):
```dart
        Row(children: [
          Expanded(child: TextField(controller: _wetter, decoration: const InputDecoration(labelText: 'Wetter'))),
          SprachMikro(mikroId: 'dik-wetter', kompakt: true, onEndText: (t) => setState(() => _wetter.text = (_wetter.text + ' ' + t).trim())),
        ]),
```
Massnahmen & Notiz (in `_seiteKennzahlen()`) analog:
```dart
      Row(children: [
        Expanded(child: TextField(controller: _massnahmen, maxLines: 2, decoration: const InputDecoration(labelText: 'Massnahmen'))),
        SprachMikro(mikroId: 'dik-massnahmen', kompakt: true, onEndText: (t) => setState(() => _massnahmen.text = (_massnahmen.text + ' ' + t).trim())),
      ]),
      Row(children: [
        Expanded(child: TextField(controller: _notiz, maxLines: 2, decoration: const InputDecoration(labelText: 'Notiz'))),
        SprachMikro(mikroId: 'dik-notiz', kompakt: true, onEndText: (t) => setState(() => _notiz.text = (_notiz.text + ' ' + t).trim())),
      ]),
```
(Die bisherigen nackten `TextField(controller: _wetter …/_massnahmen …/_notiz …)` dabei ersetzen — nicht zusätzlich.)

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/durchsicht/`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "feat(sprache): Diktat- + Kommando-Mikros im Durchsicht-Wizard (v1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Flow-Test mit FakeSpracheErkenner

**Files:**
- Test: `test/durchsicht/spracheingabe_flow_test.dart`

> Prüft die Kette Erkenner → Controller → onEndText (ohne Browser). Der `spracheErkennerProvider` wird mit dem Fake überschrieben.

- [ ] **Step 1: Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/fake_sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

void main() {
  test('Controller routet End-Transkript an aktives Mikro; Interim separat', () async {
    final fake = FakeSpracheErkenner();
    final c = ProviderContainer(overrides: [spracheErkennerProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    final ctrl = c.read(sprachControllerProvider.notifier);

    final empfangen = <String>[];
    await ctrl.starten('m1', empfangen.add);
    expect(c.read(sprachControllerProvider).aktivesMikro, 'm1');

    fake.sende('brutwaben fuenf', endgueltig: false);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(sprachControllerProvider).interim, 'brutwaben fuenf');
    expect(empfangen, isEmpty);

    fake.sende('brutwaben 5', endgueltig: true);
    await Future<void>.delayed(Duration.zero);
    expect(empfangen, ['brutwaben 5']);
    expect(c.read(sprachControllerProvider).interim, '');

    await ctrl.stoppen();
    expect(c.read(sprachControllerProvider).aktivesMikro, isNull);
  });
}
```

- [ ] **Step 2: Run → PASS**

Run: `flutter test test/durchsicht/spracheingabe_flow_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git -C D:/Projekte/Bienen/bienen_app add test/durchsicht/spracheingabe_flow_test.dart
git -C D:/Projekte/Bienen/bienen_app commit -m "test(sprache): Flow-Test Controller↔Fake-Erkenner

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Abschluss — Voll-Check, Version, Browser-Verifikation, Deploy

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Version-Bump**

`version: 1.26.1+48` → `version: 1.27.0+49`.

- [ ] **Step 2: Voll-Analyse + Tests**

Run: `cd /d/Projekte/Bienen/bienen_app && flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: alle grün (neue: deutsche_zahl, sprach_kommando, spracheingabe_flow).

- [ ] **Step 3: Browser-Verifikation (Chrome, manuell)**

Dev-Server starten; im Wizard prüfen:
- Kommando-Mikro Kontext: „Temperatur 22", „Weiselzustand weiselrichtig" → Felder gesetzt, Quittung erscheint.
- Kommando-Mikro Kennzahlen: „Königin ja", „Brutwaben 5", „Brutbild geschlossen", „Pollen viel", „Auffälligkeit Varroa" → Felder/Chips gesetzt.
- Diktat-Mikro Notiz: gesprochener Satz landet im Feld.
- Live-Transkript erscheint während des Sprechens; „nicht erkannt" bei Unsinn.
- Firefox (falls verfügbar): Mikros ausgeblendet, Tippen funktioniert.

- [ ] **Step 4: Deploy**

Run: `bash deploy.sh`
Expected: Build + gh-pages + Live-Flip auf v1.27.0 (bei DNS-Fehler erneut ausführen).

- [ ] **Step 5: Commit Version + Status**

```bash
git -C D:/Projekte/Bienen/bienen_app add pubspec.yaml
git -C D:/Projekte/Bienen/bienen_app commit -m "chore(sprache): v1.27.0 Spracheingabe v1

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git -C D:/Projekte/Bienen/bienen_app status
```

---

## Self-Review-Notizen
- **Reihenfolge:** Parser (1–2) rein & getestet vor der Verdrahtung (7). Erkenner-Interface/Fake (3) vor Controller (5) & Flow-Test (8). Web-Kapsel (4) analyze-only, manuell in Task 9.
- **Ein aktives Mikro:** der Controller stoppt implizit das alte, weil `starten` denselben Erkenner neu bindet und `aktivesMikro` überschreibt; das Widget zeigt nur für `aktivesMikro==id` den Aktiv-Zustand.
- **Additiv:** `SprachMikro` rendert nichts, wenn `verfuegbar==false` → keine Regression in Nicht-Chrome-Browsern; Speichern/Tippen nie blockiert.
- **js_interop-Risiko:** Task 4 ist die einzige nicht-unit-getestete Stelle → in Task 9 manuell in Chrome verifiziert; öffentliche Schnittstelle stabil, falls Interop-Details ans SDK angepasst werden müssen.
- **Abweichung von Spec §9 (bewusst):** die **haptische Vibration** ist im v1-Plan NICHT enthalten — sie bräuchte eine zweite js_interop-Fläche (`navigator.vibrate`) und wirkt ohnehin nur auf Android. Die sichtbare Quittung (SnackBar) deckt das Feedback ab; Vibration = leichtgewichtiger Nachtrag nach dem realen Feld-Test. Wird beim Übergang dem User genannt.
