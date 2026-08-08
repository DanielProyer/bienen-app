# Spracheingabe — Bauabschnitt 1: Fundament

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development`
> (empfohlen) oder `superpowers:executing-plans`. Schritte nutzen Kästchen (`- [ ]`) zur Nachverfolgung.

**Ziel:** Die getestete Grundlage für den Screen „Spracheingabe" — vier Migrationen, die
Domänenmodelle, ein Gateway mit Fake und fünf reine Funktionen nach TDD. **Ohne Oberfläche.**

**Architektur:** Reine Dart-Funktionen tragen die gesamte Logik (Messen, Korrigieren, Lernen) und
sind ohne Flutter, ohne Netz und ohne Datenbank prüfbar. Darüber liegt ein schmales Gateway gegen
Supabase, das dieselbe Schnittstelle auch als Fake anbietet. Die Datenbank hält vier getrennte
Tabellen, damit ein Anbieter später gegen den vorhandenen Bestand gemessen werden kann, ohne alte
Messwerte anzutasten.

**Tech-Stack:** Flutter Web 3.41, Dart 3, Supabase (Postgres 17, RLS), `supabase_flutter`.

**Grundlage:** `docs/superpowers/specs/2026-08-08-spracheingabe-training-design.md`

---

## Warum die Migrationen T und nicht S heissen

Die Buchstaben laufen alphabetisch (zuletzt `R01_recherche_fotos.sql`). **S01–S04 sind in der
Tonmitschnitt-Spec bereits vergeben** — für `durchsicht_aufnahmen`, den Audio-Bucket, die
Verhörer-Tabelle und die Aufbewahrung. Sie sind noch nicht gebaut, aber reserviert. Dieser Plan
nimmt deshalb **T01–T04** und lässt S frei, damit die Nummern beim Bau des Tonmitschnitts nicht
kollidieren.

## Dateien

| Datei | Verantwortung |
|---|---|
| `lib/features/spracheingabe/domain/fachwort_treffer.dart` | **verschoben** aus `durchsicht/sprache/domain/` — Trefferzählung, unverändert |
| `lib/features/spracheingabe/domain/wortfehlerrate.dart` | Wortfehlerrate für Satzkarten |
| `lib/features/spracheingabe/domain/korrektur_anwendung.dart` | Regeln anwenden, Ersetzungen ausweisen |
| `lib/features/spracheingabe/domain/verhoerer_diff.dart` | Paare aus Erkanntem und Korrigiertem |
| `lib/features/spracheingabe/domain/lernschwelle.dart` | Darf aus einem Verhörer eine Regel werden? |
| `lib/features/spracheingabe/domain/sprach_modelle.dart` | Karte, Probe, Ergebnis, Korrektur |
| `lib/features/spracheingabe/data/spracheingabe_gateway.dart` | Supabase-Zugriff |
| `lib/features/spracheingabe/data/fake_spracheingabe_gateway.dart` | Fake für Tests |
| `supabase/migrations/T01_sprach_karten.sql` … `T04_…` | Datenbank |

**Warum ein eigener Feature-Ordner:** Der Screen ist ein eigenes Modul mit eigener Route, kein
Teil des Durchsicht-Wizards. `fachwort_treffer.dart` zieht mit um, weil es künftig mit der
Erkennungslogik zusammen geändert wird — und weil nur der eigene Test darauf zeigt, kostet der
Umzug genau eine Importzeile.

---

## Task 1: Trefferzählung umziehen

**Dateien:**
- Verschieben: `lib/features/durchsicht/sprache/domain/fachwort_treffer.dart` → `lib/features/spracheingabe/domain/fachwort_treffer.dart`
- Verschieben: `test/sprache/fachwort_treffer_test.dart` → `test/spracheingabe/fachwort_treffer_test.dart`

- [ ] **Schritt 1: Verschieben**

```bash
mkdir -p lib/features/spracheingabe/domain lib/features/spracheingabe/data test/spracheingabe
git mv lib/features/durchsicht/sprache/domain/fachwort_treffer.dart lib/features/spracheingabe/domain/fachwort_treffer.dart
git mv test/sprache/fachwort_treffer_test.dart test/spracheingabe/fachwort_treffer_test.dart
```

- [ ] **Schritt 2: Import im Test anpassen**

In `test/spracheingabe/fachwort_treffer_test.dart` Zeile 2 ersetzen:

```dart
import 'package:bienen_app/features/spracheingabe/domain/fachwort_treffer.dart';
```

- [ ] **Schritt 3: Tests laufen lassen**

Run: `flutter test test/spracheingabe/fachwort_treffer_test.dart`
Erwartet: `All tests passed!` (7 Tests)

- [ ] **Schritt 4: Sicherstellen, dass nichts anderes darauf zeigt**

Run: `grep -rn "durchsicht/sprache/domain/fachwort_treffer" lib test`
Erwartet: keine Ausgabe

- [ ] **Schritt 5: Committen**

```bash
git add -A && git commit -m "Spracheingabe: Trefferzaehlung ins neue Feature verschoben"
```

---

## Task 2: Wortfehlerrate (TDD)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/wortfehlerrate.dart`
- Test: `test/spracheingabe/wortfehlerrate_test.dart`

Die Trefferzählung sagt, ob die Fachbegriffe ankamen. Sie sagt **nichts** darüber, ob der Rest des
Satzes zerfiel. Genau dafür ist dieses Mass da.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart';

void main() {
  test('gleicher Text ergibt null Fehler', () {
    expect(wortfehlerrate(soll: 'Königin auf Wabe acht', ist: 'Königin auf Wabe acht'), 0.0);
  });

  test('ein falsches Wort von vieren ergibt ein Viertel', () {
    expect(wortfehlerrate(soll: 'Königin auf Wabe acht', ist: 'Königin auf Wabe achtzig'),
        closeTo(0.25, 0.001));
  });

  test('Gross-/Kleinschreibung und Satzzeichen zählen nicht', () {
    expect(wortfehlerrate(soll: 'Keine Weiselzellen, alles ruhig.', ist: 'keine weiselzellen alles ruhig'),
        0.0);
  });

  test('fehlendes Wort zählt als Fehler', () {
    expect(wortfehlerrate(soll: 'Brut in allen Stadien', ist: 'Brut in Stadien'),
        closeTo(0.25, 0.001));
  });

  test('zusätzlich erfundenes Wort zählt als Fehler', () {
    expect(wortfehlerrate(soll: 'Brut in allen Stadien', ist: 'Brut in allen frischen Stadien'),
        closeTo(0.25, 0.001));
  });

  test('leeres Ist-Transkript ergibt volle Fehlerrate', () {
    expect(wortfehlerrate(soll: 'Königin gesehen', ist: ''), 1.0);
  });

  test('leerer Soll-Text ergibt null statt Division durch null', () {
    expect(wortfehlerrate(soll: '', ist: 'irgendwas'), 0.0);
  });

  test('mehr erfundene Wörter als Soll-Wörter ergibt über 1.0 und wird NICHT gekappt', () {
    // Genau der Fall, den Whisper bei Stille produziert. Eine gekappte Zahl
    // wuerde ihn wie einen gewoehnlichen Fehlschlag aussehen lassen.
    final r = wortfehlerrate(soll: 'Varroa', ist: 'ich habe heute nichts gesagt aber trotzdem');
    expect(r, greaterThan(1.0));
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/wortfehlerrate_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: wortfehlerrate.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
/// Zerlegt einen Text in vergleichbare Woerter.
///
/// Bewusst grosszuegig normalisiert: Gross-/Kleinschreibung und Satzzeichen
/// sind fuer die Frage „hat der Erkenner es verstanden" belanglos, und die
/// Anbieter setzen beides unterschiedlich. Wer hier streng vergliche, wuerde
/// vor allem Formatierungsunterschiede messen.
List<String> woerterVon(String text) => RegExp(r'[\p{L}\p{N}]+', unicode: true)
    .allMatches(text.toLowerCase())
    .map((m) => m[0]!)
    .toList();

/// Wortfehlerrate zwischen Soll- und Ist-Text.
///
/// Das klassische Mass der Spracherkennung: (Ersetzungen + Einfuegungen +
/// Loeschungen) geteilt durch die Anzahl Soll-Woerter. 0.0 ist fehlerfrei.
///
/// **Werte ueber 1.0 sind moeglich und werden absichtlich NICHT gekappt.**
/// Sie entstehen, wenn der Erkenner mehr erfindet, als dastand — genau das
/// Verhalten, das Whisper bei Stille zeigt. Eine auf 1.0 gedeckelte Zahl
/// wuerde diesen Fall wie einen gewoehnlichen Fehlschlag aussehen lassen.
double wortfehlerrate({required String soll, required String ist}) {
  final s = woerterVon(soll);
  final i = woerterVon(ist);
  if (s.isEmpty) return 0.0; // nichts zu treffen — keine Division durch null
  return _abstand(s, i) / s.length;
}

/// Levenshtein-Abstand auf Wortebene, zeilenweise gerechnet.
int _abstand(List<String> a, List<String> b) {
  var vorige = List<int>.generate(b.length + 1, (j) => j);
  for (var x = 1; x <= a.length; x++) {
    final aktuelle = List<int>.filled(b.length + 1, 0);
    aktuelle[0] = x;
    for (var y = 1; y <= b.length; y++) {
      final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
      final ersetzen = vorige[y - 1] + kosten;
      final loeschen = vorige[y] + 1;
      final einfuegen = aktuelle[y - 1] + 1;
      aktuelle[y] = ersetzen < loeschen
          ? (ersetzen < einfuegen ? ersetzen : einfuegen)
          : (loeschen < einfuegen ? loeschen : einfuegen);
    }
    vorige = aktuelle;
  }
  return vorige[b.length];
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/wortfehlerrate_test.dart`
Erwartet: `All tests passed!` (8 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/wortfehlerrate.dart test/spracheingabe/wortfehlerrate_test.dart
git commit -m "Spracheingabe: Wortfehlerrate als reine Funktion, 8 Tests"
```

---

## Task 3: Korrekturen anwenden (TDD)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/korrektur_anwendung.dart`
- Test: `test/spracheingabe/korrektur_anwendung_test.dart`

Diese Funktion gibt **zwei** Dinge zurück: den korrigierten Text und die Liste der Ersetzungen. Die
Liste ist keine Zugabe — ohne sie liesse sich keine Stelle markieren und keine einzeln zurücknehmen,
und die Ersetzung wäre still. Genau das wurde verworfen.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/korrektur_anwendung.dart';

const _weisel = Korrekturregel(falsch: 'weissenzellen', richtig: 'Weiselzellen');
const _milben = Korrekturregel(falsch: 'Minuten', richtig: 'Milben');

void main() {
  test('ohne Regeln bleibt der Text unangetastet', () {
    final k = korrekturenAnwenden(transkript: 'fünf Minuten gefunden', regeln: const []);
    expect(k.text, 'fünf Minuten gefunden');
    expect(k.ersetzungen, isEmpty);
  });

  test('ersetzt und weist die Ersetzung aus', () {
    final k = korrekturenAnwenden(transkript: 'fünf Minuten gefunden', regeln: const [_milben]);
    expect(k.text, 'fünf Milben gefunden');
    expect(k.ersetzungen, hasLength(1));
    expect(k.ersetzungen.first.vorher, 'Minuten');
    expect(k.ersetzungen.first.nachher, 'Milben');
    expect(k.text.substring(k.ersetzungen.first.start,
        k.ersetzungen.first.start + k.ersetzungen.first.laenge), 'Milben');
  });

  test('Gross-/Kleinschreibung der Regel ist egal', () {
    final k = korrekturenAnwenden(transkript: 'Weissenzellen offen', regeln: const [_weisel]);
    expect(k.text, 'Weiselzellen offen');
  });

  test('Satzzeichen bleiben stehen', () {
    final k = korrekturenAnwenden(transkript: 'keine weissenzellen, alles ruhig.', regeln: const [_weisel]);
    expect(k.text, 'keine Weiselzellen, alles ruhig.');
  });

  test('ein Teilwort wird NICHT ersetzt', () {
    // "Minutenzeiger" enthaelt "Minuten", ist aber ein anderes Wort. Ein
    // Teilstring-Ersatz wuerde hier Unsinn erzeugen — anders als beim ZAEHLEN,
    // wo Teiltreffer erwuenscht sind (siehe fachwort_treffer.dart).
    final k = korrekturenAnwenden(transkript: 'der Minutenzeiger', regeln: const [_milben]);
    expect(k.text, 'der Minutenzeiger');
    expect(k.ersetzungen, isEmpty);
  });

  test('bereits Ersetztes wird nicht erneut ersetzt', () {
    // Regelkette a->b, b->c darf b ergeben, nicht c.
    final k = korrekturenAnwenden(transkript: 'alpha', regeln: const [
      Korrekturregel(falsch: 'alpha', richtig: 'beta'),
      Korrekturregel(falsch: 'beta', richtig: 'gamma'),
    ]);
    expect(k.text, 'beta');
    expect(k.ersetzungen, hasLength(1));
  });

  test('mehrere Ersetzungen behalten korrekte Positionen trotz Längenänderung', () {
    final k = korrekturenAnwenden(
        transkript: 'weissenzellen und Minuten', regeln: const [_weisel, _milben]);
    expect(k.text, 'Weiselzellen und Milben');
    expect(k.ersetzungen, hasLength(2));
    for (final e in k.ersetzungen) {
      expect(k.text.substring(e.start, e.start + e.laenge), e.nachher);
    }
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/korrektur_anwendung_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: korrektur_anwendung.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
/// Eine gelernte Lautvariante: „so klingt es bei mir" → „so heisst es richtig".
class Korrekturregel {
  final String falsch;
  final String richtig;
  const Korrekturregel({required this.falsch, required this.richtig});
}

/// Eine vorgenommene Ersetzung, bezogen auf den ERGEBNISTEXT.
/// `start` und `laenge` zeigen auf die eingesetzte Fassung, damit die Anzeige
/// die Stelle ohne Nachrechnen einfaerben kann.
class Ersetzung {
  final int start;
  final int laenge;
  final String vorher;
  final String nachher;
  const Ersetzung({
    required this.start,
    required this.laenge,
    required this.vorher,
    required this.nachher,
  });
}

class Korrigiert {
  final String text;
  final List<Ersetzung> ersetzungen;
  const Korrigiert({required this.text, required this.ersetzungen});
}

/// Wendet gelernte Regeln auf ein Transkript an.
///
/// **Ganze Woerter, kein Teilstring.** Beim ZAEHLEN ist ein Teiltreffer
/// erwuenscht („Varroamilben" enthaelt „Varroa"); beim ERSETZEN waere er
/// zerstoererisch — aus „Minutenzeiger" wuerde „Milbenzeiger".
///
/// Regeln greifen nur einmal: Durchlaufen wird der EINGABETEXT, nie das
/// Ergebnis. Sonst koennte eine Regelkette (a→b, b→c) ein Wort weiterreichen,
/// bis niemand mehr nachvollzieht, woher es kam.
///
/// v1 kennt nur Ein-Wort-Regeln. Alle Verhoerer des Feldtests sind
/// Ein-Wort-Faelle (weissenzellen, Minuten, schwadentrieb); mehrteilige Regeln
/// kaemen erst mit Belegen dafuer, dass es sie braucht.
Korrigiert korrekturenAnwenden({
  required String transkript,
  required List<Korrekturregel> regeln,
}) {
  if (regeln.isEmpty || transkript.isEmpty) {
    return Korrigiert(text: transkript, ersetzungen: const []);
  }
  final nachSchluessel = <String, String>{
    for (final r in regeln)
      if (r.falsch.trim().isNotEmpty) r.falsch.toLowerCase(): r.richtig,
  };

  final aus = StringBuffer();
  final ersetzungen = <Ersetzung>[];
  var gelesen = 0;

  for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(transkript)) {
    aus.write(transkript.substring(gelesen, m.start));
    final original = m[0]!;
    final ersatz = nachSchluessel[original.toLowerCase()];
    if (ersatz == null) {
      aus.write(original);
    } else {
      ersetzungen.add(Ersetzung(
        start: aus.length,
        laenge: ersatz.length,
        vorher: original,
        nachher: ersatz,
      ));
      aus.write(ersatz);
    }
    gelesen = m.end;
  }
  aus.write(transkript.substring(gelesen));

  return Korrigiert(text: aus.toString(), ersetzungen: ersetzungen);
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/korrektur_anwendung_test.dart`
Erwartet: `All tests passed!` (7 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/korrektur_anwendung.dart test/spracheingabe/korrektur_anwendung_test.dart
git commit -m "Spracheingabe: Korrekturanwendung mit ausgewiesenen Ersetzungen, 7 Tests"
```

---

## Task 4: Verhörer aus dem Unterschied ziehen (TDD)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/verhoerer_diff.dart`
- Test: `test/spracheingabe/verhoerer_diff_test.dart`

Beim freien Sprechen korrigiert der Nutzer das Transkript. Aus dem Unterschied entstehen die
Kandidatenpaare. **Nur Ersetzungen zählen** — ein zusätzlich getipptes oder gelöschtes Wort ist
kein Verhörer, sondern eine Ergänzung.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/verhoerer_diff.dart';

void main() {
  test('gleicher Text ergibt keine Paare', () {
    expect(verhoererAus(erkannt: 'Königin gesehen', korrigiert: 'Königin gesehen'), isEmpty);
  });

  test('ein ersetztes Wort ergibt genau ein Paar', () {
    final p = verhoererAus(erkannt: 'fünf Minuten gefunden', korrigiert: 'fünf Milben gefunden');
    expect(p, hasLength(1));
    expect(p.first.falsch, 'minuten');
    expect(p.first.richtig, 'Milben');
  });

  test('ein eingefügtes Wort ergibt KEIN Paar', () {
    expect(verhoererAus(erkannt: 'Brut in Stadien', korrigiert: 'Brut in allen Stadien'), isEmpty);
  });

  test('ein gelöschtes Wort ergibt KEIN Paar', () {
    expect(verhoererAus(erkannt: 'Brut in allen Stadien', korrigiert: 'Brut in Stadien'), isEmpty);
  });

  test('zwei Ersetzungen ergeben zwei Paare', () {
    final p = verhoererAus(
        erkannt: 'weissenzellen und Minuten', korrigiert: 'Weiselzellen und Milben');
    expect(p.map((e) => e.richtig), ['Weiselzellen', 'Milben']);
  });

  test('reiner Gross-/Kleinschreibungsunterschied ergibt kein Paar', () {
    expect(verhoererAus(erkannt: 'varroa gesehen', korrigiert: 'Varroa gesehen'), isEmpty);
  });

  test('leere Eingaben stürzen nicht ab', () {
    expect(verhoererAus(erkannt: '', korrigiert: ''), isEmpty);
    expect(verhoererAus(erkannt: '', korrigiert: 'Varroa'), isEmpty);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/verhoerer_diff_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: verhoerer_diff.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart' show woerterVon;

/// Ein Kandidatenpaar. `falsch` steht normalisiert (klein), weil danach
/// gesucht wird; `richtig` behaelt die Schreibweise des Nutzers, weil sie im
/// Text erscheint.
class Verhoererpaar {
  final String falsch;
  final String richtig;
  const Verhoererpaar({required this.falsch, required this.richtig});

  @override
  bool operator ==(Object other) =>
      other is Verhoererpaar && other.falsch == falsch && other.richtig == richtig;

  @override
  int get hashCode => Object.hash(falsch, richtig);
}

/// Zieht Verhoererpaare aus dem Unterschied zwischen Erkanntem und der vom
/// Nutzer korrigierten Fassung.
///
/// **Nur 1:1-Ersetzungen werden Paare.** Ein eingefuegtes Wort ist eine
/// Ergaenzung, ein geloeschtes eine Streichung — beides sagt nichts darueber
/// aus, wie ein Wort bei diesem Sprecher klingt. Sie als Paare zu fuehren
/// wuerde die Regeltabelle mit Rauschen fuellen.
List<Verhoererpaar> verhoererAus({required String erkannt, required String korrigiert}) {
  final a = woerterVon(erkannt);
  // Die Roh-Woerter der korrigierten Fassung, um die Schreibweise zu behalten.
  final bRoh = RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(korrigiert)
      .map((m) => m[0]!)
      .toList();
  final b = bRoh.map((w) => w.toLowerCase()).toList();
  if (a.isEmpty || b.isEmpty) return const [];

  // Levenshtein-Matrix, danach rueckwaerts durch die Entscheidungen laufen.
  final d = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var x = 0; x <= a.length; x++) {
    d[x][0] = x;
  }
  for (var y = 0; y <= b.length; y++) {
    d[0][y] = y;
  }
  for (var x = 1; x <= a.length; x++) {
    for (var y = 1; y <= b.length; y++) {
      final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
      final e = d[x - 1][y - 1] + kosten;
      final l = d[x - 1][y] + 1;
      final i = d[x][y - 1] + 1;
      d[x][y] = e < l ? (e < i ? e : i) : (l < i ? l : i);
    }
  }

  final paare = <Verhoererpaar>[];
  var x = a.length, y = b.length;
  while (x > 0 && y > 0) {
    final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
    if (d[x][y] == d[x - 1][y - 1] + kosten) {
      if (kosten == 1) {
        paare.add(Verhoererpaar(falsch: a[x - 1], richtig: bRoh[y - 1]));
      }
      x--;
      y--;
    } else if (d[x][y] == d[x - 1][y] + 1) {
      x--; // Streichung
    } else {
      y--; // Ergaenzung
    }
  }
  return paare.reversed.toList();
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/verhoerer_diff_test.dart`
Erwartet: `All tests passed!` (7 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/verhoerer_diff.dart test/spracheingabe/verhoerer_diff_test.dart
git commit -m "Spracheingabe: Verhoererpaare aus dem Unterschied, nur Ersetzungen, 7 Tests"
```

---

## Task 5: Lernschwelle (TDD)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/lernschwelle.dart`
- Test: `test/spracheingabe/lernschwelle_test.dart`

Der Wächter, der verhindert, dass die App Zufall lernt — und dass sie je einen Seuchenbegriff
boostet.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';

void main() {
  test('ein einzelner Verhörer wird KEINE Regel', () {
    expect(darfRegelWerden(treffer: 1, richtig: 'Weiselzellen'), isFalse);
  });

  test('ab dem zweiten Mal wird er zur Regel', () {
    expect(darfRegelWerden(treffer: 2, richtig: 'Weiselzellen'), isTrue);
  });

  test('Seuchenbegriffe werden nie zur Regel, egal wie oft', () {
    for (final s in ['Faulbrut', 'Sauerbrut', 'Nosema']) {
      expect(darfRegelWerden(treffer: 99, richtig: s), isFalse, reason: s);
    }
  });

  test('Alltagswörter mit Sonderbedeutung ebenfalls nicht', () {
    for (final s in ['Beute', 'Windel', 'Stifte', 'Schied']) {
      expect(darfRegelWerden(treffer: 99, richtig: s), isFalse, reason: s);
    }
  });

  test('die Sperre greift unabhängig von der Schreibweise', () {
    expect(darfRegelWerden(treffer: 99, richtig: 'faulbrut'), isFalse);
    expect(darfRegelWerden(treffer: 99, richtig: '  FAULBRUT  '), isFalse);
  });

  test('leeres Zielwort wird nie zur Regel', () {
    expect(darfRegelWerden(treffer: 99, richtig: '   '), isFalse);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/lernschwelle_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: lernschwelle.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
/// Wie oft derselbe Verhoerer auftreten muss, bevor er zur Regel wird.
///
/// Raeuspern, ein Windstoss oder ein verschlucktes Wort erzeugen einmalige
/// Abweichungen. Wuerde daraus sofort eine Regel, lernte die App Zufall — und
/// wendete ihn danach auf jedes Transkript an. Zwei ist der billigste
/// verfuegbare Schutz dagegen.
const int lernschwelle = 2;

/// Begriffe, die NIE geboostet oder ersetzt werden (Entscheid D-99d).
///
/// Seuchen: Wortlisten koennen Begriffe EINFUEGEN, die nie gesagt wurden. Ein
/// halluzinierter Faulbrut-Befund im vorbefuellten Formular waere gravierender
/// als ein fehlender — diese Begriffe loest die Sprachmodell-Stufe aus dem
/// Kontext auf.
///
/// Alltagswoerter mit imkerlicher Sonderbedeutung: regulaere deutsche Woerter.
/// Sie zu ersetzen erzeugt Uebererkennung im uebrigen Text.
const Set<String> gesperrteBegriffe = {
  'faulbrut',
  'sauerbrut',
  'amerikanische faulbrut',
  'europäische faulbrut',
  'nosema',
  'beute',
  'windel',
  'stifte',
  'schied',
  'rahmen',
};

/// Entscheidet, ob aus einem beobachteten Verhoerer eine Korrekturregel werden
/// darf.
bool darfRegelWerden({required int treffer, required String richtig}) {
  final ziel = richtig.trim().toLowerCase();
  if (ziel.isEmpty) return false;
  if (gesperrteBegriffe.contains(ziel)) return false;
  return treffer >= lernschwelle;
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/lernschwelle_test.dart`
Erwartet: `All tests passed!` (6 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/lernschwelle.dart test/spracheingabe/lernschwelle_test.dart
git commit -m "Spracheingabe: Lernschwelle und Sperrliste, 6 Tests"
```

---

## Task 6: Migration T01 — `sprach_karten`

**Dateien:**
- Erstellen: `supabase/migrations/T01_sprach_karten.sql`

> **FREIGABE:** Diese Migration wird Daniel **vor** dem Anwenden vorgelegt. Nicht ungefragt gegen
> die Produktionsdatenbank laufen lassen.

- [ ] **Schritt 1: Datei anlegen**

```sql
-- T01_sprach_karten.sql | Spracheingabe: der Uebungsstoff des Trainings.
-- Muster aus R01 (recherche_fotos). Buchstabe T, weil S01-S04 in der
-- Tonmitschnitt-Spec fuer durchsicht_aufnahmen reserviert sind.
--
-- person_id ist NULLABLE und das ist Absicht: Die Startliste gilt fuer alle im
-- Betrieb, eine aus einem Verhoerer entstandene Karte gehoert zu einer Stimme.
create table if not exists public.sprach_karten (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid,
  art text not null check (art in ('wort','satz')),
  soll_text text not null check (length(btrim(soll_text)) > 0),
  pruefbegriffe text[] not null default '{}',
  herkunft text not null default 'eigen' check (herkunft in ('start','verhoerer','eigen')),
  aktiv boolean not null default true,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sprach_karten enable row level security;
revoke all on public.sprach_karten from anon, public;
grant select, insert, update, delete on public.sprach_karten to authenticated;

-- Leseweg des Drills: aktive Karten des Betriebs, eigene und allgemeine.
create index if not exists idx_sprach_karten_stapel
  on public.sprach_karten (betrieb_id, aktiv, person_id);

drop trigger if exists trg_sprach_karten_actor on public.sprach_karten;
create trigger trg_sprach_karten_actor before insert or update
  on public.sprach_karten for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_karten_updated on public.sprach_karten;
create trigger trg_sprach_karten_updated before update
  on public.sprach_karten for each row execute function private.set_updated_at();

-- Sichtbar sind allgemeine Karten (person_id is null) und die eigenen.
drop policy if exists sprach_karten_sel on public.sprach_karten;
create policy sprach_karten_sel on public.sprach_karten
  for select to authenticated using (
    betrieb_id in (select private.meine_betrieb_ids())
    and (person_id is null or person_id = private.current_app_user())
  );
drop policy if exists sprach_karten_ins on public.sprach_karten;
create policy sprach_karten_ins on public.sprach_karten
  for insert to authenticated with check (
    private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user())
  );
drop policy if exists sprach_karten_upd on public.sprach_karten;
create policy sprach_karten_upd on public.sprach_karten
  for update to authenticated
  using (private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user()))
  with check (private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user()));
drop policy if exists sprach_karten_del on public.sprach_karten;
create policy sprach_karten_del on public.sprach_karten
  for delete to authenticated using (
    private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user())
  );

-- ROLLBACK: drop table if exists public.sprach_karten;
```

- [ ] **Schritt 2: Daniel vorlegen und Freigabe abwarten**

Die Migration im Wortlaut zeigen, mit der Frage nach Freigabe. **Erst danach** anwenden.

- [ ] **Schritt 3: Anwenden und prüfen**

Über den Supabase-MCP `apply_migration` mit Namen `T01_sprach_karten`, danach:

Run: `get_advisors(project_id, type: "security")`
Erwartet: **0 neue Findings** gegenüber dem Stand davor.

- [ ] **Schritt 4: Committen**

```bash
git add supabase/migrations/T01_sprach_karten.sql
git commit -m "Migration T01: sprach_karten (Uebungsstoff), RLS eigen plus allgemein"
```

---

## Task 7: Migration T02 — `sprach_proben` und Bucket

**Dateien:**
- Erstellen: `supabase/migrations/T02_sprach_proben.sql`

> **FREIGABE erforderlich** wie bei T01.

- [ ] **Schritt 1: Datei anlegen**

```sql
-- T02_sprach_proben.sql | Spracheingabe: jede Aufnahme, plus privater Bucket.
--
-- PERSONENBEZOGEN wie benachrichtigungs_einstellungen (O01), nicht nach dem
-- ueblichen Mitglieder-Muster: Eine Sprachaufnahme ist die Stimme eines
-- Menschen und geht Kollegen desselben Betriebs nichts an.
--
-- soll_text wird als SCHNAPPSCHUSS gehalten, nicht nur ueber karte_id
-- verwiesen. Aendert sich die Karte spaeter, bleiben alte Messungen
-- auswertbar — sonst maesse man gegen einen Text, der beim Sprechen gar nicht
-- dastand.
create table if not exists public.sprach_proben (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid not null,
  karte_id uuid references public.sprach_karten(id) on delete set null,
  soll_text text not null default '',
  modus text not null check (modus in ('drill','frei')),
  storage_path text not null
    check (storage_path like (betrieb_id::text || '/' || person_id::text || '/%')),
  dauer_ms integer not null check (dauer_ms >= 0),
  groesse_b integer not null check (groesse_b >= 0),
  mime text not null default 'audio/webm',
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sprach_proben enable row level security;
revoke all on public.sprach_proben from anon, public;
grant select, insert, update, delete on public.sprach_proben to authenticated;

create index if not exists idx_sprach_proben_person
  on public.sprach_proben (betrieb_id, person_id, created_at desc);

drop trigger if exists trg_sprach_proben_actor on public.sprach_proben;
create trigger trg_sprach_proben_actor before insert or update
  on public.sprach_proben for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_proben_updated on public.sprach_proben;
create trigger trg_sprach_proben_updated before update
  on public.sprach_proben for each row execute function private.set_updated_at();

drop policy if exists sprach_proben_sel on public.sprach_proben;
create policy sprach_proben_sel on public.sprach_proben
  for select to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_proben_ins on public.sprach_proben;
create policy sprach_proben_ins on public.sprach_proben
  for insert to authenticated
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_proben_upd on public.sprach_proben;
create policy sprach_proben_upd on public.sprach_proben
  for update to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Loeschen ist hier ausdruecklich erlaubt: "alle meine Trainingsdaten loeschen"
-- muss moeglich sein (Datenschutz), im Gegensatz zu O01.
drop policy if exists sprach_proben_del on public.sprach_proben;
create policy sprach_proben_del on public.sprach_proben
  for delete to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));

insert into storage.buckets (id, name, public)
  values ('sprach-proben', 'sprach-proben', false)
  on conflict (id) do nothing;

-- Pfad <betrieb_id>/<person_id>/<uuid>.webm — BEIDE Ebenen werden geprueft.
-- Nur den Betrieb zu pruefen wuerde den personenbezogenen Schutz der Tabelle
-- auf dem Storage-Weg wieder aufheben.
drop policy if exists auth_sel_sprach_proben on storage.objects;
create policy auth_sel_sprach_proben on storage.objects for select to authenticated
  using (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(objects.name))[1])::uuid)
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);
drop policy if exists auth_ins_sprach_proben on storage.objects;
create policy auth_ins_sprach_proben on storage.objects for insert to authenticated
  with check (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(objects.name))[1])::uuid)
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);
drop policy if exists auth_del_sprach_proben on storage.objects;
create policy auth_del_sprach_proben on storage.objects for delete to authenticated
  using (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(objects.name))[1])::uuid)
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);

-- ROLLBACK:
--   drop policy if exists auth_sel_sprach_proben on storage.objects;
--   drop policy if exists auth_ins_sprach_proben on storage.objects;
--   drop policy if exists auth_del_sprach_proben on storage.objects;
--   delete from storage.objects where bucket_id = 'sprach-proben';
--   delete from storage.buckets where id = 'sprach-proben';
--   drop table if exists public.sprach_proben;
```

> **Achtung, Lehre aus D-78:** `storage.foldername(name)` wird hier **explizit als
> `objects.name` qualifiziert**. In P01 band ein unqualifiziertes `name` in einer korrelierten
> Subquery an `materials.name` statt an `storage.objects.name` — die Policy verglich Material-ID
> mit Material-*Namen* und war dauerhaft falsch. Migration P02 musste das reparieren.

- [ ] **Schritt 2: Daniel vorlegen und Freigabe abwarten**

- [ ] **Schritt 3: Anwenden und prüfen**

Über `apply_migration` mit Namen `T02_sprach_proben`, danach `get_advisors(security)`.
Erwartet: **0 neue Findings**.

- [ ] **Schritt 4: Committen**

```bash
git add supabase/migrations/T02_sprach_proben.sql
git commit -m "Migration T02: sprach_proben und privater Bucket, personenbezogen auf beiden Ebenen"
```

---

## Task 8: Migration T03 — `sprach_ergebnisse`

**Dateien:**
- Erstellen: `supabase/migrations/T03_sprach_ergebnisse.sql`

> **FREIGABE erforderlich** wie bei T01.

- [ ] **Schritt 1: Datei anlegen**

```sql
-- T03_sprach_ergebnisse.sql | Spracheingabe: je Probe x Anbieter x Wortliste eine Messung.
--
-- BEWUSST OHNE Eindeutigkeit ueber die Zeit. Eine zweite Messung derselben
-- Probe legt eine NEUE Zeile an, statt die erste zu ueberschreiben. Genau das
-- ist der Zweck dieser Tabelle: Ein neuer Anbieter oder eine neue
-- Modellgeneration wird gegen den vorhandenen Bestand gemessen, und die Frage
-- "war ElevenLabs im Januar besser als im Juli" beantworten Daten statt
-- Erinnerung.
create table if not exists public.sprach_ergebnisse (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  probe_id uuid not null references public.sprach_proben(id) on delete cascade,
  anbieter text not null check (length(btrim(anbieter)) > 0),
  modell text not null default '',
  mit_wortliste boolean not null,
  transkript text not null default '',
  treffer_quote numeric(5,4),
  wortfehlerrate numeric(6,4),
  dauer_ms integer,
  fehler text,
  gemessen_am timestamptz not null default now(),
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sprach_ergebnisse enable row level security;
revoke all on public.sprach_ergebnisse from anon, public;
grant select, insert, update, delete on public.sprach_ergebnisse to authenticated;

create index if not exists idx_sprach_ergebnisse_probe
  on public.sprach_ergebnisse (probe_id, anbieter, gemessen_am desc);

drop trigger if exists trg_sprach_ergebnisse_actor on public.sprach_ergebnisse;
create trigger trg_sprach_ergebnisse_actor before insert or update
  on public.sprach_ergebnisse for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_ergebnisse_updated on public.sprach_ergebnisse;
create trigger trg_sprach_ergebnisse_updated before update
  on public.sprach_ergebnisse for each row execute function private.set_updated_at();

-- Die Berechtigung haengt an der PROBE, nicht an dieser Zeile.
-- Diese Tabelle sieht wie eine reine Messtabelle aus, enthaelt aber das
-- Transkript — also den Wortlaut des Gesagten. Waere sie nach dem
-- Mitglieder-Muster lesbar, koennte jedes Mitglied nachlesen, was ein anderes
-- gesprochen hat, und der Schutz auf sprach_proben waere wertlos.
create or replace function private.eigene_sprach_probe(p_probe_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.sprach_proben p
    where p.id = p_probe_id and p.person_id = private.current_app_user()
  );
$$;
revoke execute on function private.eigene_sprach_probe(uuid) from anon, authenticated, public;
grant execute on function private.eigene_sprach_probe(uuid) to authenticated;

drop policy if exists sprach_ergebnisse_sel on public.sprach_ergebnisse;
create policy sprach_ergebnisse_sel on public.sprach_ergebnisse
  for select to authenticated using (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_ins on public.sprach_ergebnisse;
create policy sprach_ergebnisse_ins on public.sprach_ergebnisse
  for insert to authenticated with check (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_upd on public.sprach_ergebnisse;
create policy sprach_ergebnisse_upd on public.sprach_ergebnisse
  for update to authenticated
  using (private.eigene_sprach_probe(probe_id))
  with check (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_del on public.sprach_ergebnisse;
create policy sprach_ergebnisse_del on public.sprach_ergebnisse
  for delete to authenticated using (private.eigene_sprach_probe(probe_id));

-- ROLLBACK:
--   drop table if exists public.sprach_ergebnisse;
--   drop function if exists private.eigene_sprach_probe(uuid);
```

- [ ] **Schritt 2: Daniel vorlegen und Freigabe abwarten**

- [ ] **Schritt 3: Anwenden und prüfen**

Über `apply_migration` mit Namen `T03_sprach_ergebnisse`, danach `get_advisors(security)`.
Erwartet: **0 neue Findings**.

- [ ] **Schritt 4: Isolation nachweisen (nicht nur behaupten)**

Über `execute_sql` als Rolle `authenticated` mit einer fremden `person_id` prüfen, dass die
Ergebniszeilen einer fremden Probe **nicht** lesbar sind:

```sql
-- Erwartet: 0 Zeilen
select count(*) from public.sprach_ergebnisse e
join public.sprach_proben p on p.id = e.probe_id
where p.person_id <> private.current_app_user();
```

- [ ] **Schritt 5: Committen**

```bash
git add supabase/migrations/T03_sprach_ergebnisse.sql
git commit -m "Migration T03: sprach_ergebnisse, Berechtigung haengt an der Probe"
```

---

## Task 9: Migration T04 — `sprach_korrekturen`

**Dateien:**
- Erstellen: `supabase/migrations/T04_sprach_korrekturen.sql`

> **FREIGABE erforderlich** wie bei T01.

- [ ] **Schritt 1: Datei anlegen**

```sql
-- T04_sprach_korrekturen.sql | Spracheingabe: die gelernten Lautvarianten.
-- Setzt S03 der Tonmitschnitt-Spec um. Personenbezogen wie O01 —
-- Daniel und Lorena sprechen unterschiedlich (D-98b).
--
-- `treffer` zaehlt, wie oft derselbe Verhoerer beobachtet wurde. Erst ab der
-- Lernschwelle (2, siehe lernschwelle.dart) wird `aktiv` gesetzt; darunter ist
-- die Zeile nur eine Beobachtung.
create table if not exists public.sprach_korrekturen (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid not null,
  falsch text not null check (length(btrim(falsch)) > 0),
  richtig text not null check (length(btrim(richtig)) > 0),
  treffer integer not null default 1 check (treffer >= 1),
  quelle text not null default 'training' check (quelle in ('training','durchsicht','manuell')),
  aktiv boolean not null default false,
  zuletzt_am timestamptz not null default now(),
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, person_id, falsch)
);
alter table public.sprach_korrekturen enable row level security;
revoke all on public.sprach_korrekturen from anon, public;
grant select, insert, update, delete on public.sprach_korrekturen to authenticated;

create index if not exists idx_sprach_korrekturen_aktiv
  on public.sprach_korrekturen (betrieb_id, person_id, aktiv);

drop trigger if exists trg_sprach_korrekturen_actor on public.sprach_korrekturen;
create trigger trg_sprach_korrekturen_actor before insert or update
  on public.sprach_korrekturen for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_korrekturen_updated on public.sprach_korrekturen;
create trigger trg_sprach_korrekturen_updated before update
  on public.sprach_korrekturen for each row execute function private.set_updated_at();

drop policy if exists sprach_korrekturen_sel on public.sprach_korrekturen;
create policy sprach_korrekturen_sel on public.sprach_korrekturen
  for select to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_korrekturen_ins on public.sprach_korrekturen;
create policy sprach_korrekturen_ins on public.sprach_korrekturen
  for insert to authenticated
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_korrekturen_upd on public.sprach_korrekturen;
create policy sprach_korrekturen_upd on public.sprach_korrekturen
  for update to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Loeschen erlaubt: eine falsch gelernte Regel muss verschwinden koennen,
-- sonst schleppt man sie jahrelang mit.
drop policy if exists sprach_korrekturen_del on public.sprach_korrekturen;
create policy sprach_korrekturen_del on public.sprach_korrekturen
  for delete to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));

-- ROLLBACK: drop table if exists public.sprach_korrekturen;
```

- [ ] **Schritt 2: Daniel vorlegen und Freigabe abwarten**

- [ ] **Schritt 3: Anwenden und prüfen**

Über `apply_migration` mit Namen `T04_sprach_korrekturen`, danach `get_advisors(security)`.
Erwartet: **0 neue Findings**.

- [ ] **Schritt 4: Committen**

```bash
git add supabase/migrations/T04_sprach_korrekturen.sql
git commit -m "Migration T04: sprach_korrekturen, setzt S03 der Tonmitschnitt-Spec um"
```

---

## Task 10: Domänenmodelle

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/sprach_modelle.dart`
- Test: `test/spracheingabe/sprach_modelle_test.dart`

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

void main() {
  test('Karte liest sich aus JSON, pruefbegriffe nie null', () {
    final k = SprachKarte.fromJson(const {
      'id': 'k1', 'art': 'satz', 'soll_text': 'Königin auf Wabe acht',
      'pruefbegriffe': ['Königin'], 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.art, KartenArt.satz);
    expect(k.pruefbegriffe, ['Königin']);

    final ohne = SprachKarte.fromJson(const {
      'id': 'k2', 'art': 'wort', 'soll_text': 'Varroa', 'herkunft': 'eigen', 'aktiv': true,
    });
    expect(ohne.pruefbegriffe, isEmpty);
    expect(ohne.art, KartenArt.wort);
  });

  test('bei einer Wortkarte sind die Prüfbegriffe der Soll-Text selbst', () {
    // Sonst haette eine Wortkarte nichts zu zaehlen.
    final k = SprachKarte.fromJson(const {
      'id': 'k3', 'art': 'wort', 'soll_text': 'Weiselzellen', 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.zuZaehlen, ['Weiselzellen']);
  });

  test('bei einer Satzkarte sind die Prüfbegriffe die hinterlegten', () {
    final k = SprachKarte.fromJson(const {
      'id': 'k4', 'art': 'satz', 'soll_text': 'keine Weiselzellen gesehen',
      'pruefbegriffe': ['Weiselzellen'], 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.zuZaehlen, ['Weiselzellen']);
  });

  test('Probe und Ergebnis lesen sich aus JSON', () {
    final p = SprachProbe.fromJson(const {
      'id': 'p1', 'person_id': 'u1', 'karte_id': 'k1', 'soll_text': 'Varroa',
      'modus': 'drill', 'storage_path': 'b/u/x.webm', 'dauer_ms': 1200,
      'groesse_b': 4096, 'mime': 'audio/webm',
    });
    expect(p.modus, ProbenModus.drill);
    expect(p.dauerMs, 1200);

    final e = SprachErgebnis.fromJson(const {
      'id': 'e1', 'probe_id': 'p1', 'anbieter': 'infomaniak', 'modell': 'whisper',
      'mit_wortliste': true, 'transkript': 'Varroa', 'treffer_quote': 1.0,
      'wortfehlerrate': 0.0, 'dauer_ms': 4300,
    });
    expect(e.anbieter, 'infomaniak');
    expect(e.trefferQuote, 1.0);
    expect(e.fehler, isNull);
  });

  test('Korrektur wird erst ab der Lernschwelle als aktiv gemeldet', () {
    final k = SprachKorrektur.fromJson(const {
      'id': 'c1', 'person_id': 'u1', 'falsch': 'weissenzellen',
      'richtig': 'Weiselzellen', 'treffer': 1, 'quelle': 'training', 'aktiv': false,
    });
    expect(k.aktiv, isFalse);
  });

  test('nurAktive lässt unscharfe Beobachtungen draussen', () {
    // Der Verbraucher soll nicht selbst an `aktiv` denken muessen.
    final scharf = SprachKorrektur.fromJson(const {
      'id': 'c1', 'person_id': 'u1', 'falsch': 'weissenzellen',
      'richtig': 'Weiselzellen', 'treffer': 2, 'quelle': 'training', 'aktiv': true,
    });
    final beobachtung = SprachKorrektur.fromJson(const {
      'id': 'c2', 'person_id': 'u1', 'falsch': 'minuten',
      'richtig': 'Milben', 'treffer': 1, 'quelle': 'training', 'aktiv': false,
    });
    final regeln = SprachKorrektur.nurAktive([scharf, beobachtung]);
    expect(regeln.map((r) => r.richtig), ['Weiselzellen']);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/sprach_modelle_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: sprach_modelle.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
import 'package:bienen_app/features/spracheingabe/domain/korrektur_anwendung.dart';

enum KartenArt { wort, satz }

enum ProbenModus { drill, frei }

T _ausText<T extends Enum>(List<T> werte, Object? roh, T standard) {
  final s = (roh as String?)?.trim();
  for (final w in werte) {
    if (w.name == s) return w;
  }
  return standard;
}

/// Eine Uebungskarte.
class SprachKarte {
  final String id;
  final String? personId;
  final KartenArt art;
  final String sollText;
  final List<String> pruefbegriffe;
  final String herkunft;
  final bool aktiv;

  const SprachKarte({
    required this.id,
    required this.art,
    required this.sollText,
    this.personId,
    this.pruefbegriffe = const [],
    this.herkunft = 'eigen',
    this.aktiv = true,
  });

  /// Was fuer die Trefferzaehlung erwartet wird.
  ///
  /// Bei einer Wortkarte ist der Soll-Text selbst der einzige Pruefbegriff —
  /// sonst haette sie nichts zu zaehlen. Bei einer Satzkarte gelten die
  /// hinterlegten Begriffe.
  List<String> get zuZaehlen =>
      art == KartenArt.wort ? [sollText.trim()] : pruefbegriffe;

  factory SprachKarte.fromJson(Map<String, dynamic> j) => SprachKarte(
        id: j['id'] as String,
        personId: j['person_id'] as String?,
        art: _ausText(KartenArt.values, j['art'], KartenArt.wort),
        sollText: (j['soll_text'] as String?) ?? '',
        pruefbegriffe:
            ((j['pruefbegriffe'] as List?) ?? const []).map((e) => e as String).toList(),
        herkunft: (j['herkunft'] as String?) ?? 'eigen',
        aktiv: (j['aktiv'] as bool?) ?? true,
      );

  Map<String, dynamic> toInsertJson() => {
        if (personId != null) 'person_id': personId,
        'art': art.name,
        'soll_text': sollText,
        'pruefbegriffe': pruefbegriffe,
        'herkunft': herkunft,
        'aktiv': aktiv,
      };
}

/// Eine Aufnahme.
class SprachProbe {
  final String id;
  final String personId;
  final String? karteId;
  final String sollText;
  final ProbenModus modus;
  final String storagePath;
  final int dauerMs;
  final int groesseB;
  final String mime;

  const SprachProbe({
    required this.id,
    required this.personId,
    required this.sollText,
    required this.modus,
    required this.storagePath,
    required this.dauerMs,
    required this.groesseB,
    this.karteId,
    this.mime = 'audio/webm',
  });

  factory SprachProbe.fromJson(Map<String, dynamic> j) => SprachProbe(
        id: j['id'] as String,
        personId: j['person_id'] as String,
        karteId: j['karte_id'] as String?,
        sollText: (j['soll_text'] as String?) ?? '',
        modus: _ausText(ProbenModus.values, j['modus'], ProbenModus.frei),
        storagePath: j['storage_path'] as String,
        dauerMs: (j['dauer_ms'] as num?)?.toInt() ?? 0,
        groesseB: (j['groesse_b'] as num?)?.toInt() ?? 0,
        mime: (j['mime'] as String?) ?? 'audio/webm',
      );

  Map<String, dynamic> toInsertJson() => {
        'person_id': personId,
        if (karteId != null) 'karte_id': karteId,
        'soll_text': sollText,
        'modus': modus.name,
        'storage_path': storagePath,
        'dauer_ms': dauerMs,
        'groesse_b': groesseB,
        'mime': mime,
      };
}

/// Eine Messung: was ein Anbieter aus einer Probe gemacht hat.
class SprachErgebnis {
  final String id;
  final String probeId;
  final String anbieter;
  final String modell;
  final bool mitWortliste;
  final String transkript;
  final double? trefferQuote;
  final double? wortfehlerrate;
  final int? dauerMs;
  final String? fehler;

  const SprachErgebnis({
    required this.id,
    required this.probeId,
    required this.anbieter,
    required this.mitWortliste,
    this.modell = '',
    this.transkript = '',
    this.trefferQuote,
    this.wortfehlerrate,
    this.dauerMs,
    this.fehler,
  });

  factory SprachErgebnis.fromJson(Map<String, dynamic> j) => SprachErgebnis(
        id: j['id'] as String,
        probeId: j['probe_id'] as String,
        anbieter: j['anbieter'] as String,
        modell: (j['modell'] as String?) ?? '',
        mitWortliste: (j['mit_wortliste'] as bool?) ?? false,
        transkript: (j['transkript'] as String?) ?? '',
        trefferQuote: (j['treffer_quote'] as num?)?.toDouble(),
        wortfehlerrate: (j['wortfehlerrate'] as num?)?.toDouble(),
        dauerMs: (j['dauer_ms'] as num?)?.toInt(),
        fehler: j['fehler'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'probe_id': probeId,
        'anbieter': anbieter,
        'modell': modell,
        'mit_wortliste': mitWortliste,
        'transkript': transkript,
        'treffer_quote': trefferQuote,
        'wortfehlerrate': wortfehlerrate,
        'dauer_ms': dauerMs,
        'fehler': fehler,
      };
}

/// Eine beobachtete oder gelernte Lautvariante.
class SprachKorrektur {
  final String id;
  final String personId;
  final String falsch;
  final String richtig;
  final int treffer;
  final String quelle;
  final bool aktiv;

  const SprachKorrektur({
    required this.id,
    required this.personId,
    required this.falsch,
    required this.richtig,
    this.treffer = 1,
    this.quelle = 'training',
    this.aktiv = false,
  });

  factory SprachKorrektur.fromJson(Map<String, dynamic> j) => SprachKorrektur(
        id: j['id'] as String,
        personId: j['person_id'] as String,
        falsch: j['falsch'] as String,
        richtig: j['richtig'] as String,
        treffer: (j['treffer'] as num?)?.toInt() ?? 1,
        quelle: (j['quelle'] as String?) ?? 'training',
        aktiv: (j['aktiv'] as bool?) ?? false,
      );

  /// Uebersetzt in die Form, die `korrekturenAnwenden` erwartet.
  ///
  /// Steht hier und nicht beim Aufrufer, damit es genau EINE Stelle gibt, an
  /// der aus einer gespeicherten Zeile eine wirksame Regel wird — sonst
  /// entstuende die Umwandlung in jedem Verbraucher neu, und irgendeiner
  /// vergaesse `aktiv` zu pruefen.
  Korrekturregel get regel => Korrekturregel(falsch: falsch, richtig: richtig);

  /// Nur scharfe Regeln aus einer Liste — der uebliche Einstieg.
  static List<Korrekturregel> nurAktive(Iterable<SprachKorrektur> alle) =>
      alle.where((k) => k.aktiv).map((k) => k.regel).toList();
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/sprach_modelle_test.dart`
Erwartet: `All tests passed!` (6 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/sprach_modelle.dart test/spracheingabe/sprach_modelle_test.dart
git commit -m "Spracheingabe: Domaenenmodelle Karte, Probe, Ergebnis, Korrektur"
```

---

## Task 11: Gateway und Fake

**Dateien:**
- Erstellen: `lib/features/spracheingabe/data/spracheingabe_gateway.dart`
- Erstellen: `lib/features/spracheingabe/data/fake_spracheingabe_gateway.dart`
- Test: `test/spracheingabe/fake_gateway_test.dart`

Die Schnittstelle wird als abstrakte Klasse definiert, damit der Fake sie erfüllt und spätere
Widget-Tests ohne Netz auskommen — dasselbe Vorgehen wie bei `fake_voelker_gateway.dart`.

- [ ] **Schritt 1: Schnittstelle und Supabase-Umsetzung schreiben**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Zugriff auf den Trainingsbestand.
///
/// RLS laesst nur die eigenen Zeilen durch (T01-T04) — deshalb braucht keine
/// Abfrage hier einen person_id-Filter. Beim SCHREIBEN muss die person_id
/// trotzdem mit, weil sie Teil der `with check`-Bedingung ist.
abstract class SpracheingabeGateway {
  Future<List<SprachKarte>> kartenLaden();
  Future<SprachKarte> karteAnlegen(SprachKarte karte);
  Future<SprachProbe> probeAnlegen(SprachProbe probe);
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis ergebnis);
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId);
  Future<List<SprachKorrektur>> korrekturenLaden();

  /// Zaehlt einen beobachteten Verhoerer hoch und schaltet die Regel scharf,
  /// sobald die Lernschwelle erreicht ist.
  Future<SprachKorrektur?> verhoererMelden({
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  });
}

class SupabaseSpracheingabeGateway implements SpracheingabeGateway {
  final SupabaseClient _c;
  SupabaseSpracheingabeGateway(this._c);

  @override
  Future<List<SprachKarte>> kartenLaden() async {
    final res = await _c.from('sprach_karten').select().eq('aktiv', true);
    return (res as List).map((j) => SprachKarte.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<SprachKarte> karteAnlegen(SprachKarte karte) async {
    final res =
        await _c.from('sprach_karten').insert(karte.toInsertJson()).select().single();
    return SprachKarte.fromJson(res);
  }

  @override
  Future<SprachProbe> probeAnlegen(SprachProbe probe) async {
    final res =
        await _c.from('sprach_proben').insert(probe.toInsertJson()).select().single();
    return SprachProbe.fromJson(res);
  }

  @override
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis ergebnis) async {
    final res = await _c
        .from('sprach_ergebnisse')
        .insert(ergebnis.toInsertJson())
        .select()
        .single();
    return SprachErgebnis.fromJson(res);
  }

  @override
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId) async {
    final res = await _c
        .from('sprach_ergebnisse')
        .select()
        .eq('probe_id', probeId)
        .order('gemessen_am', ascending: false);
    return (res as List)
        .map((j) => SprachErgebnis.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SprachKorrektur>> korrekturenLaden() async {
    final res = await _c.from('sprach_korrekturen').select();
    return (res as List)
        .map((j) => SprachKorrektur.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SprachKorrektur?> verhoererMelden({
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  }) async {
    final schluessel = falsch.trim().toLowerCase();
    if (schluessel.isEmpty || richtig.trim().isEmpty) return null;

    final vorhanden = await _c
        .from('sprach_korrekturen')
        .select()
        .eq('falsch', schluessel)
        .maybeSingle();

    final treffer = vorhanden == null ? 1 : ((vorhanden['treffer'] as num).toInt() + 1);
    final aktiv = darfRegelWerden(treffer: treffer, richtig: richtig);

    final res = await _c
        .from('sprach_korrekturen')
        .upsert({
          'person_id': personId,
          'falsch': schluessel,
          'richtig': richtig,
          'treffer': treffer,
          'quelle': quelle,
          'aktiv': aktiv,
          'zuletzt_am': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'betrieb_id,person_id,falsch')
        .select()
        .single();
    return SprachKorrektur.fromJson(res);
  }
}
```

- [ ] **Schritt 2: Fake schreiben**

```dart
import 'package:bienen_app/features/spracheingabe/data/spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Speicherfassung des Gateways fuer Tests — kein Netz, keine Datenbank.
class FakeSpracheingabeGateway implements SpracheingabeGateway {
  final List<SprachKarte> karten = [];
  final List<SprachProbe> proben = [];
  final List<SprachErgebnis> ergebnisse = [];
  final List<SprachKorrektur> korrekturen = [];
  int _lauf = 0;

  String _id(String praefix) => '$praefix${++_lauf}';

  @override
  Future<List<SprachKarte>> kartenLaden() async =>
      karten.where((k) => k.aktiv).toList();

  @override
  Future<SprachKarte> karteAnlegen(SprachKarte karte) async {
    final neu = SprachKarte(
      id: _id('k'),
      personId: karte.personId,
      art: karte.art,
      sollText: karte.sollText,
      pruefbegriffe: karte.pruefbegriffe,
      herkunft: karte.herkunft,
      aktiv: karte.aktiv,
    );
    karten.add(neu);
    return neu;
  }

  @override
  Future<SprachProbe> probeAnlegen(SprachProbe probe) async {
    final neu = SprachProbe(
      id: _id('p'),
      personId: probe.personId,
      karteId: probe.karteId,
      sollText: probe.sollText,
      modus: probe.modus,
      storagePath: probe.storagePath,
      dauerMs: probe.dauerMs,
      groesseB: probe.groesseB,
      mime: probe.mime,
    );
    proben.add(neu);
    return neu;
  }

  @override
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis e) async {
    final neu = SprachErgebnis(
      id: _id('e'),
      probeId: e.probeId,
      anbieter: e.anbieter,
      modell: e.modell,
      mitWortliste: e.mitWortliste,
      transkript: e.transkript,
      trefferQuote: e.trefferQuote,
      wortfehlerrate: e.wortfehlerrate,
      dauerMs: e.dauerMs,
      fehler: e.fehler,
    );
    ergebnisse.add(neu);
    return neu;
  }

  @override
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId) async =>
      ergebnisse.where((e) => e.probeId == probeId).toList();

  @override
  Future<List<SprachKorrektur>> korrekturenLaden() async => List.of(korrekturen);

  @override
  Future<SprachKorrektur?> verhoererMelden({
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  }) async {
    final schluessel = falsch.trim().toLowerCase();
    if (schluessel.isEmpty || richtig.trim().isEmpty) return null;

    final i = korrekturen.indexWhere((k) => k.falsch == schluessel);
    final treffer = i < 0 ? 1 : korrekturen[i].treffer + 1;
    final neu = SprachKorrektur(
      id: i < 0 ? _id('c') : korrekturen[i].id,
      personId: personId,
      falsch: schluessel,
      richtig: richtig,
      treffer: treffer,
      quelle: quelle,
      aktiv: darfRegelWerden(treffer: treffer, richtig: richtig),
    );
    if (i < 0) {
      korrekturen.add(neu);
    } else {
      korrekturen[i] = neu;
    }
    return neu;
  }
}
```

- [ ] **Schritt 3: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/data/fake_spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

void main() {
  test('erster Verhörer bleibt inaktiv, zweiter schaltet die Regel scharf', () async {
    final g = FakeSpracheingabeGateway();

    final erst = await g.verhoererMelden(
        personId: 'u1', falsch: 'weissenzellen', richtig: 'Weiselzellen', quelle: 'training');
    expect(erst!.treffer, 1);
    expect(erst.aktiv, isFalse, reason: 'ein einzelner Verhörer darf keine Regel sein');

    final zweit = await g.verhoererMelden(
        personId: 'u1', falsch: 'Weissenzellen', richtig: 'Weiselzellen', quelle: 'training');
    expect(zweit!.treffer, 2);
    expect(zweit.aktiv, isTrue);
    expect(g.korrekturen, hasLength(1), reason: 'derselbe Verhörer legt keine zweite Zeile an');
  });

  test('ein Seuchenbegriff wird auch nach vielen Treffern nicht scharf', () async {
    final g = FakeSpracheingabeGateway();
    for (var i = 0; i < 5; i++) {
      await g.verhoererMelden(
          personId: 'u1', falsch: 'faulbrot', richtig: 'Faulbrut', quelle: 'training');
    }
    expect(g.korrekturen.single.treffer, 5);
    expect(g.korrekturen.single.aktiv, isFalse);
  });

  test('nur aktive Karten werden geladen', () async {
    final g = FakeSpracheingabeGateway();
    await g.karteAnlegen(const SprachKarte(
        id: '', art: KartenArt.wort, sollText: 'Varroa', aktiv: true));
    await g.karteAnlegen(const SprachKarte(
        id: '', art: KartenArt.wort, sollText: 'Altlast', aktiv: false));
    final geladen = await g.kartenLaden();
    expect(geladen.map((k) => k.sollText), ['Varroa']);
  });

  test('Ergebnisse werden ihrer Probe zugeordnet', () async {
    final g = FakeSpracheingabeGateway();
    final p = await g.probeAnlegen(const SprachProbe(
        id: '', personId: 'u1', sollText: 'Varroa', modus: ProbenModus.drill,
        storagePath: 'b/u/x.webm', dauerMs: 1000, groesseB: 2048));
    await g.ergebnisAnlegen(SprachErgebnis(
        id: '', probeId: p.id, anbieter: 'infomaniak', mitWortliste: true, transkript: 'Varroa'));
    await g.ergebnisAnlegen(SprachErgebnis(
        id: '', probeId: 'fremd', anbieter: 'elevenlabs', mitWortliste: true, transkript: 'x'));
    final e = await g.ergebnisseZu(p.id);
    expect(e, hasLength(1));
    expect(e.single.anbieter, 'infomaniak');
  });
}
```

- [ ] **Schritt 4: Tests laufen lassen**

Run: `flutter test test/spracheingabe/fake_gateway_test.dart`
Erwartet: `All tests passed!` (4 Tests)

- [ ] **Schritt 5: Gesamtlauf und Analyse**

Run: `flutter analyze lib test`
Erwartet: `No issues found!`

Run: `flutter test`
Erwartet: alle Tests grün, Anzahl gegenüber vorher um **38** gestiegen
(8 + 7 + 7 + 6 + 6 + 4; die 7 verschobenen zählen unverändert mit).

- [ ] **Schritt 6: Committen**

```bash
git add lib/features/spracheingabe/data test/spracheingabe/fake_gateway_test.dart
git commit -m "Spracheingabe: Gateway mit Fake, Lernschwelle im Schreibweg verankert"
```

---

## Task 12: Startstapel und Wächter gegen die Fachwortliste

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/startstapel.dart`
- Test: `test/spracheingabe/startstapel_test.dart`

T01 legt die Tabelle an, füllt sie aber nicht — und **darf es auch nicht**: Ein `insert` in einer
Migration bräuchte eine feste `betrieb_id` und wäre damit ein Mandanten-Hardcode. Der Stapel wird
deshalb aus einer Dart-Konstante heraus je Betrieb angelegt (die Bedienung dazu kommt in
Bauabschnitt 2).

Damit entsteht aber ein zweites Problem: Die Fachwortliste stünde dann **zweimal** im Projekt — in
`supabase/functions/transkription/fachwoerter.ts` für die Erkenner und in Dart für den Stapel. Zwei
Wahrheiten, die auseinanderlaufen, ohne dass es jemand merkt. Der Wächter unten schliesst das, indem
er die TypeScript-Datei liest und vergleicht.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/startstapel.dart';

void main() {
  test('der Stapel findet überhaupt Wortkarten', () {
    // Leerlauf-Sicherung (Lehre aus D-85): Ohne sie faerbt eine leere Liste
    // alle folgenden Pruefungen gruen.
    final woerter = startstapel.where((k) => k.art == KartenArt.wort);
    expect(woerter.length, greaterThan(20));
  });

  test('jede Wortkarte hat Herkunft "start" und ist aktiv', () {
    for (final k in startstapel) {
      expect(k.herkunft, 'start', reason: k.sollText);
      expect(k.aktiv, isTrue, reason: k.sollText);
      expect(k.personId, isNull, reason: '${k.sollText} muss für alle im Betrieb gelten');
    }
  });

  test('die Wortkarten stimmen zeichengleich mit fachwoerter.ts überein', () {
    // Zwei Wahrheiten fuer dieselbe Liste sind eine Zeitbombe: Der Erkenner
    // boostet dann andere Begriffe, als der Drill uebt.
    final datei = File('supabase/functions/transkription/fachwoerter.ts');
    expect(datei.existsSync(), isTrue, reason: 'fachwoerter.ts nicht gefunden');
    final inhalt = datei.readAsStringSync();
    final block = RegExp(r'FACHWOERTER:\s*string\[\]\s*=\s*\[(.*?)\]', dotAll: true)
        .firstMatch(inhalt);
    expect(block, isNotNull, reason: 'FACHWOERTER-Block nicht erkannt');
    final ausTs = RegExp(r"'([^']+)'")
        .allMatches(block![1]!)
        .map((m) => m[1]!)
        .toList();
    expect(ausTs.length, greaterThan(20), reason: 'Parser hat nichts gefunden');

    final ausDart = startstapel
        .where((k) => k.art == KartenArt.wort)
        .map((k) => k.sollText)
        .toList();
    expect(ausDart, ausTs);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/startstapel_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: startstapel.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Der Übungsstapel, mit dem ein Betrieb startet.
///
/// Die Wortkarten sind zeichengleich mit `FACHWOERTER` aus
/// `supabase/functions/transkription/fachwoerter.ts` — ein Test haelt das fest.
/// Zwei Wahrheiten fuer dieselbe Liste waeren eine Zeitbombe: Der Erkenner
/// boostete dann andere Begriffe, als der Drill uebt.
///
/// Was hier BEWUSST fehlt (Entscheid D-99d): Seuchenbegriffe und Alltagswoerter
/// mit imkerlicher Sonderbedeutung. Sie stehen in `gesperrteBegriffe`.
///
/// Die `id` bleibt leer — sie wird beim Anlegen von der Datenbank vergeben.
const List<SprachKarte> startstapel = [
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Varroa', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Varroamilbe', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Milben', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Weiselzellen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Weiselrichtigkeit', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'weiselrichtig', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'weisellos', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Drohnenbrut', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Drohnenrahmen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Schwarmtrieb', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Schwarmzellen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Ableger', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Kunstschwarm', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Dadant', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Zander', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Mittelwand', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Absperrgitter', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Honigraum', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Brutraum', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Wabengasse', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Gemüll', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Ameisensäure', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Oxalsäure', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Sublimation', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Trachtende', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Räuberei', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Kalkbrut', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Buckfast', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Bienenflucht', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Futterteig', herkunft: 'start'),
];
```

> **Die Satzkarten fehlen hier absichtlich.** Sie sollen aus echten
> Durchsicht-Formulierungen stammen; die beste Quelle ist die erste ausgewertete Aufnahme (siehe
> „Vor der Umsetzung zu klären" in der Spec). Erfundene Sätze jetzt hineinzuschreiben hiesse, den
> Drill gegen eine Sprache zu üben, die niemand spricht. Sie kommen in Bauabschnitt 2 dazu, wenn
> das Material vorliegt.

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/startstapel_test.dart`
Erwartet: `All tests passed!` (3 Tests)

- [ ] **Schritt 5: Wächter gegenprobe — er muss rot werden können**

Ein Wort in `startstapel.dart` absichtlich verfälschen (z. B. `Varroa` → `Varoa`), Test laufen
lassen, **Fehlschlag bestätigen**, Änderung zurücknehmen. Ein Wächter, der nie rot war, ist kein
Wächter (Hausregel aus D-90b/D-93a).

- [ ] **Schritt 6: Gesamtlauf**

Run: `flutter analyze lib test`
Erwartet: `No issues found!`

Run: `flutter test`
Erwartet: alle grün, gegenüber dem Ausgangsstand **41** Tests mehr.

- [ ] **Schritt 7: Committen**

```bash
git add lib/features/spracheingabe/domain/startstapel.dart test/spracheingabe/startstapel_test.dart
git commit -m "Spracheingabe: Startstapel plus Waechter gegen fachwoerter.ts"
```

---

## Abschluss von Bauabschnitt 1

Danach steht: vier Tabellen mit nachgewiesener Mandanten- und Personentrennung, fünf getestete
reine Funktionen, die Domänenmodelle und ein Gateway mit Fake. **Der Screen selbst kommt in
Bauabschnitt 2** (js-interop-Aufnahme, JWT-Eingang der Edge Function, Segment „Üben").

Nicht vergessen: `docs/decision-log.md` um die Entscheide dieses Abschnitts ergänzen — die
Lernschwelle von zwei, die Personenbindung der Ergebnistabelle und die unbegrenzte Aufbewahrung
der Trainingsproben als begründete Ausnahme zu S04.

---

## Nachtrag: Befunde des Abschlussreviews (2026-08-08)

> **Die Codeblöcke der Tasks oben zeigen den Stand VOR dem Abschlussreview.** Nach der Umsetzung
> hat ein unabhängiger Review (Fable 5, Auftrag: widerlegen statt bestätigen) fünf Mängel gefunden,
> vier davon im hier vorgegebenen Code. Sie sind behoben; massgeblich ist der Code im Repo.
> Die Migrationen waren zu diesem Zeitpunkt **noch nicht angewandt** — genau dafür lag der
> Freigabepunkt dort.

**BLOCKER — `sprach_ergebnisse.betrieb_id` war an nichts gebunden.** Alle vier Policies prüften nur
`eigene_sprach_probe(probe_id)`, nie die `betrieb_id` der Zeile. Sie kommt aus dem Default
`private.aktive_betrieb_id()`, also aus dem JWT des Augenblicks. Folge: Eine Ergebniszeile konnte
einen anderen Mandanten tragen als ihre Probe — böswillig durch Mitschicken einer fremden
`betrieb_id`, versehentlich durch einen Betriebswechsel zwischen Aufnahme und Nachmessung, die die
Spec ausdrücklich vorsieht. *Behoben* mit `unique (betrieb_id, id)` in T02 und einem
zusammengesetzten Fremdschlüssel `(betrieb_id, probe_id)` in T03: Die Bindung erzwingt jetzt die
Datenbank, unabhängig von den Policies.

**WICHTIG — Ausgetretene Mitglieder behielten Zugriff auf `sprach_ergebnisse`.**
`eigene_sprach_probe` prüft nur die Person, nicht die Mitgliedschaft. *Behoben:* `ist_mitglied`
zusätzlich in SELECT, INSERT und UPDATE.

**WICHTIG — und die Gegenrichtung: Nach einem Austritt liessen sich die eigenen Aufnahmen nicht
mehr löschen.** Die Delete-Policies verlangten `ist_mitglied`; die Stimmdaten wären für niemanden
mehr erreichbar gewesen und nur per `service_role` zu entfernen — im Widerspruch zum
Löschversprechen der Spec. *Behoben:* Löschen hängt in T02, T03 und T04 **nur** an `person_id`.
Daraus die Regel: **Ein Austritt nimmt den Zugriff, nie das Recht, die eigene Stimme zu löschen.**

**WICHTIG — Die Sperrliste wirkte nur in eine Richtung.** `darfRegelWerden` prüfte `richtig`, nicht
`falsch`. Eine Regel `faulbrut → irgendetwas` hätte damit jeden echt gesagten Seuchenbegriff still
aus dem Transkript geschrieben — die Umkehrung genau der Gefahr, wegen der D-99d die Liste
verlangt. *Behoben:* beide Seiten werden geprüft, mit zwei neuen Tests.

**WICHTIG — `verhoererMelden` fragte ohne Betriebsfilter ab.** RLS liefert die eigenen Zeilen
*aller* Betriebe. Bei einem Mitglied zweier Betriebe hätte `.maybeSingle()` entweder hart versagt
oder den Zähler des falschen Betriebs übernommen — die Lernschwelle wäre ausgehebelt gewesen.
*Behoben:* `betriebId` ist Pflichtparameter, wird gefiltert und explizit geschrieben statt dem
Default überlassen.

Offen und bewusst zurückgestellt: das Read-Modify-Write-Fenster in `verhoererMelden` (ein
verlorenes Inkrement bei zwei fast gleichzeitigen Meldungen), eine mögliche Doppelanlage des
Startstapels, sowie `check (falsch = lower(falsch))` in T04. Alle drei gehören in Bauabschnitt 2,
wo der Schreibweg aus der Oberfläche entsteht; die saubere Lösung für die ersten beiden ist
dieselbe — eine RPC mit atomarem `on conflict do update`.
