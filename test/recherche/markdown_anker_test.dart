import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/recherche/domain/markdown_anker.dart';

void main() {
  group('markdownAnker — Slug wie GitHub ihn erzeugt', () {
    test('einfache Überschrift', () {
      expect(markdownAnker('# Titel'), 'titel');
      expect(markdownAnker('## Zwei Wörter'), 'zwei-wörter');
    });

    test('Nummerierung: Punkte fallen weg, Ziffern bleiben', () {
      // "## 1. Biologie …" -> "#1-biologie-…" (so steht es in den Recherchen)
      expect(markdownAnker('## 1. Biologie von Varroa'), '1-biologie-von-varroa');
      expect(markdownAnker('### 3.1 Der eine Fund'), '31-der-eine-fund');
    });

    test('Umlaute bleiben erhalten', () {
      expect(markdownAnker('## 4. Verfügbare Produkte'), '4-verfügbare-produkte');
      expect(markdownAnker('## Größe & Maß'), 'größe--maß');
    });

    test('Gedankenstrich verschwindet, seine Leerzeichen bleiben als --', () {
      // Der reale Fall aus Recherche 30 — hier entsteht der Doppel-Bindestrich.
      expect(
        markdownAnker('## 3. Die Fehler-Asymmetrie — der wichtigste Praxisbefund'),
        '3-die-fehler-asymmetrie--der-wichtigste-praxisbefund',
      );
    });

    test('Datumsangaben verlieren ihre Punkte', () {
      expect(
        markdownAnker('## 12. Stufe 0 durchgeführt — eigene Messungen vom 27.07.2026'),
        '12-stufe-0-durchgeführt--eigene-messungen-vom-27072026',
      );
    });

    test('Inline-Auszeichnung zählt nicht mit', () {
      expect(markdownAnker('## 1. Biologie von *Varroa destructor*'),
          '1-biologie-von-varroa-destructor');
      expect(markdownAnker('## **Fett** und `Code`'), 'fett-und-code');
    });

    test('Links in Überschriften: nur der Linktext zählt', () {
      expect(markdownAnker('## Siehe [Kapitel 5](#kapitel-5)'), 'siehe-kapitel-5');
    });

    test('führende und folgende Leerzeichen stören nicht', () {
      expect(markdownAnker('##   Titel mit Raum   '), 'titel-mit-raum');
    });
  });

  group('zerlegeInAbschnitte', () {
    test('Text ohne Überschrift ergibt einen ankerlosen Abschnitt', () {
      final a = zerlegeInAbschnitte('Nur Fliesstext.\nZweite Zeile.');
      expect(a, hasLength(1));
      expect(a.single.anker, isNull);
      expect(a.single.text, contains('Nur Fliesstext.'));
    });

    test('Präambel vor der ersten Überschrift bleibt erhalten', () {
      final a = zerlegeInAbschnitte('Vorspann\n\n# Erstes\nInhalt');
      expect(a, hasLength(2));
      expect(a.first.anker, isNull);
      expect(a.first.text.trim(), 'Vorspann');
      expect(a.last.anker, 'erstes');
    });

    test('jede Überschrift beginnt einen Abschnitt, Text bleibt zugeordnet', () {
      final a = zerlegeInAbschnitte('# A\nText A\n## B\nText B\n### C\nText C');
      expect(a.map((e) => e.anker), ['a', 'b', 'c']);
      expect(a[0].text, contains('Text A'));
      expect(a[1].text, contains('Text B'));
      expect(a[2].text, contains('Text C'));
    });

    test('die Überschriftszeile selbst bleibt im Abschnitt', () {
      // Sonst verschwindet sie beim Rendern.
      final a = zerlegeInAbschnitte('# Titel\nInhalt');
      expect(a.single.text, startsWith('# Titel'));
    });

    test('Rauten in Code-Blöcken sind KEINE Überschriften', () {
      const md = '''
# Echt

```bash
# nur ein Kommentar
## auch keiner
```

## Ebenfalls echt
''';
      final a = zerlegeInAbschnitte(md);
      expect(a.map((e) => e.anker), ['echt', 'ebenfalls-echt']);
      // Der Code-Block muss vollständig im ersten Abschnitt liegen.
      expect(a.first.text, contains('nur ein Kommentar'));
      expect(a.first.text, contains('## auch keiner'));
    });

    test('auch ~~~ zählt als Code-Zaun', () {
      const md = '# A\n~~~\n# kein Header\n~~~\n# B';
      final a = zerlegeInAbschnitte(md);
      expect(a.map((e) => e.anker), ['a', 'b']);
    });

    test('Raute ohne Leerzeichen ist keine Überschrift', () {
      // "#hashtag" ist in Markdown kein Header.
      final a = zerlegeInAbschnitte('# Echt\n#keinHeader\nText');
      expect(a, hasLength(1));
      expect(a.single.anker, 'echt');
    });

    test('doppelte Überschriften bekommen unterscheidbare Anker', () {
      // Sonst springt der zweite Verweis immer zum ersten Vorkommen.
      final a = zerlegeInAbschnitte('# Quellen\n## Quellen\n### Quellen');
      expect(a.map((e) => e.anker), ['quellen', 'quellen-1', 'quellen-2']);
    });

    test('leerer Text ergibt keine Abschnitte', () {
      expect(zerlegeInAbschnitte(''), isEmpty);
    });
  });

  group('Zusammenspiel: Verweise der echten Recherchen treffen ihr Ziel', () {
    test('Inhaltsverzeichnis und Überschriften erzeugen denselben Anker', () {
      // Auszug aus 30_Varroa_Bildzaehlung_Automatisierung.md
      const dokument = '''
# Varroa-Zählung per Foto

1. [Die Fragestellung](#1-die-fragestellung--und-was-daran-technisch-schwer-ist)
2. [Forschungsstand](#2-forschungsstand-was-nachweislich-funktioniert)

## 1. Die Fragestellung — und was daran technisch schwer ist
Text.

## 2. Forschungsstand: was nachweislich funktioniert
Text.
''';
      final anker = zerlegeInAbschnitte(dokument)
          .map((e) => e.anker)
          .whereType<String>()
          .toSet();

      // Genau die Ziele, auf die das Inhaltsverzeichnis oben verweist:
      expect(anker, contains('1-die-fragestellung--und-was-daran-technisch-schwer-ist'));
      expect(anker, contains('2-forschungsstand-was-nachweislich-funktioniert'));
    });
  });
}
