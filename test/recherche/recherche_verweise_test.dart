// Prüft die echten Recherche-Dokumente: Trifft jeder Verweis aus einem
// Inhaltsverzeichnis auch eine Überschrift?
//
// Das ist der Test, der den Anker-Fix gegen die Wirklichkeit stellt — eine
// grüne Logik nützt nichts, wenn die Slugs der 259 Verweise in den Dokumenten
// nicht dazu passen. Er findet zugleich kaputte Verzeichnisse in den Texten.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/recherche/domain/markdown_anker.dart';

void main() {
  final ordner = Directory('assets/recherche');
  final dateien = ordner
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('Recherche-Ordner ist auffindbar und gefüllt', () {
    // Ohne diese Prüfung wäre ein leerer Ordner (falscher Arbeitsordner)
    // stillschweigend grün — dieselbe Falle wie beim PII-Guard.
    expect(dateien.length, greaterThan(20),
        reason: 'Zu wenige Recherchen gefunden — falscher Arbeitsordner?');
  });

  group('Abbildungen', () {
    test('jeder Bildverweis zeigt auf eine vorhandene Datei', () {
      // Bilder stehen relativ im Dokument (bilder/30_x.jpg) und werden vom
      // Viewer auf assets/recherche/… aufgelöst. Ein Tippfehler im Pfad fiele
      // sonst erst am Bienenstand auf.
      final fehlend = <String>[];
      for (final datei in dateien) {
        final text = datei.readAsStringSync();
        for (final m in RegExp(r'!\[[^\]]*\]\(([^)]+)\)').allMatches(text)) {
          final verweis = m.group(1)!;
          if (verweis.startsWith('http')) continue; // extern: bewusst nicht gebündelt
          final pfad = verweis.startsWith('assets/')
              ? verweis
              : 'assets/recherche/$verweis';
          if (!File(pfad).existsSync()) {
            fehlend.add('${datei.path.split(RegExp(r"[\\/]")).last} → $verweis');
          }
        }
      }
      expect(fehlend, isEmpty,
          reason: 'Bildverweise ohne Datei:\n  ${fehlend.join("\n  ")}');
    });

    test('jeder Bildordner ist in pubspec.yaml eingetragen', () {
      // Der Fehler vom 2026-07-27: Die Dateien lagen in
      // assets/recherche/bilder/fund/, im pubspec stand aber nur
      // assets/recherche/bilder/ — und Asset-Ordner sind in Flutter NICHT
      // rekursiv. Ergebnis: 18 Abbildungen fehlten stumm in der App, obwohl
      // der Dateitest grün war. Dateiexistenz ist eben nicht Auslieferung.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final eingetragen = RegExp(r'^\s*-\s*(assets/[^\s#]*/)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toSet();

      final gebraucht = <String>{};
      for (final datei in dateien) {
        for (final m in RegExp(r'!\[[^\]]*\]\(([^)]+)\)')
            .allMatches(datei.readAsStringSync())) {
          final v = m.group(1)!;
          if (v.startsWith('http')) continue;
          final pfad = v.startsWith('assets/') ? v : 'assets/recherche/$v';
          gebraucht.add(pfad.substring(0, pfad.lastIndexOf('/') + 1));
        }
      }

      final fehlend = gebraucht.difference(eingetragen).toList()..sort();
      expect(fehlend, isEmpty,
          reason: 'Diese Ordner enthalten verlinkte Bilder, stehen aber NICHT '
              'in pubspec.yaml — die Bilder erscheinen dann nicht in der App:\n'
              '  ${fehlend.join("\n  ")}');
    });

    test('gebündelte Abbildungen sind klein genug für die Web-App', () {
      final ordner = Directory('assets/recherche/bilder');
      if (!ordner.existsSync()) return;
      final zuGross = ordner
          .listSync()
          .whereType<File>()
          .where((f) => f.lengthSync() > 600 * 1024)
          .map((f) => '${f.path.split(RegExp(r"[\\/]")).last} '
              '(${(f.lengthSync() / 1024).round()} KB)')
          .toList();
      expect(zuGross, isEmpty,
          reason: 'Über 600 KB — die App lädt das über Mobilfunk am Stand:\n'
              '  ${zuGross.join("\n  ")}');
    });
  });

  group('Sprungmarken der Inhaltsverzeichnisse', () {
    for (final datei in dateien) {
      final name = datei.path.split(RegExp(r'[\\/]')).last;

      test(name, () {
        final text = datei.readAsStringSync();
        // Aufgelöst wird über genau dieselbe Funktion wie im Viewer — der Test
        // prüft damit den echten Sprungweg, nicht eine Nachbildung davon.
        final ziele = zerlegeInAbschnitte(text)
            .map((a) => a.anker)
            .whereType<String>()
            .toList();

        final verweise = RegExp(r'\]\(#([^)]+)\)')
            .allMatches(text)
            .map((m) => m.group(1)!)
            .toSet();

        final ohneZiel = verweise
            .where((v) => findeAnkerZiel(ziele, v) == null)
            .toList()
          ..sort();

        expect(ohneZiel, isEmpty,
            reason: '$name: ${ohneZiel.length} Verweis(e) ohne passende '
                'Überschrift:\n  ${ohneZiel.join("\n  ")}\n'
                'Vorhandene Anker (Auszug):\n  '
                '${ziele.take(12).join("\n  ")}');
      });
    }
  });
}
