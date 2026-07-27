// Wächter gegen persönliche Daten in ausgelieferten Inhalten.
//
// Anlass (2026-07-27): Die Recherche-Assets werden mit der Web-App gebündelt
// und waren dadurch OHNE Login unter der Pages-URL abrufbar — samt exakter
// Standortadresse. Ein privates Repo hätte daran nichts geändert, weil die
// Dateien im ausgelieferten Bundle stecken.
//
// Geprüft wird, was beim Nutzer ankommt: `assets/` (gebündelt, siehe
// pubspec.yaml) und `lib/` (kompilierter Code). Nicht geprüft werden `docs/`
// und `supabase/` — die liegen zwar im öffentlichen Repo, gehen aber nicht in
// die Auslieferung; für sie ist die Repo-Sichtbarkeit die Grenze.
//
// Region und Höhe („Arosa", „1570 m") sind ausdrücklich ERLAUBT: fachlich
// nötig und nicht identifizierend. Verboten ist, was zur Haustür führt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Muster, die nicht in ausgelieferten Inhalten stehen dürfen.
///
/// Bewusst konkret statt generisch: Ein allgemeines Adress- oder E-Mail-Muster
/// würde Amtsangaben (Bauamt Arosa, Amt für Lebensmittelsicherheit) mitfangen,
/// die fachlich hingehören und öffentlich sind.
const _verboten = <String, String>{
  'Strasse + Hausnummer des Bienenstands':
      // "Tannen 85a" in jeder Schreibweise, auch ohne Leerzeichen.
      // Fängt zugleich künftige Hausnummern derselben Strasse ab.
      r'Tannen\s*\d+',
  'private E-Mail-Adresse':
      // Freemailer = privat. Behörden-/Firmenadressen bleiben erlaubt.
      r'[A-Za-z0-9._%+-]+@(gmail|gmx|hotmail|bluewin|outlook|yahoo|icloud)\.',
};

/// Dateiendungen, deren Inhalt als Text beim Nutzer ankommt.
const _textEndungen = {'.md', '.dart', '.json', '.txt', '.html', '.csv'};

Iterable<File> _textDateienIn(String pfad) sync* {
  final ordner = Directory(pfad);
  if (!ordner.existsSync()) return;
  for (final e in ordner.listSync(recursive: true)) {
    if (e is! File) continue;
    final punkt = e.path.lastIndexOf('.');
    if (punkt < 0) continue;
    if (_textEndungen.contains(e.path.substring(punkt).toLowerCase())) yield e;
  }
}

void main() {
  group('PII-Guard: ausgelieferte Inhalte', () {
    // Ohne diese Prüfung würde ein leerer Ordner (falscher Arbeitsordner,
    // umbenanntes Verzeichnis) den Test grün färben, ohne etwas zu prüfen —
    // dieselbe Falle wie ein Backup-Lauf mit leerem Warnungs-Array.
    test('findet überhaupt Dateien zum Prüfen', () {
      final anzahl = _textDateienIn('assets').length + _textDateienIn('lib').length;
      expect(anzahl, greaterThan(50),
          reason: 'Zu wenige Dateien gefunden — läuft der Test im falschen '
              'Arbeitsordner? Dann prüft er nichts und ist trotzdem grün.');
    });

    for (final eintrag in _verboten.entries) {
      test('keine ${eintrag.key} in assets/ und lib/', () {
        final muster = RegExp(eintrag.value, caseSensitive: false);
        final treffer = <String>[];

        for (final datei in [..._textDateienIn('assets'), ..._textDateienIn('lib')]) {
          final zeilen = datei.readAsLinesSync();
          for (var i = 0; i < zeilen.length; i++) {
            if (muster.hasMatch(zeilen[i])) {
              // Die Fundstelle nennen, aber nicht den Wert selbst ausgeben —
              // Testausgaben landen in CI-Logs.
              treffer.add('${datei.path}:${i + 1}');
            }
          }
        }

        expect(treffer, isEmpty,
            reason: 'Persönliche Daten in ausgelieferten Inhalten gefunden '
                '(${eintrag.key}). Diese Dateien werden mit der Web-App '
                'gebündelt und sind ohne Login abrufbar:\n'
                '${treffer.join('\n')}');
      });
    }
  });
}
