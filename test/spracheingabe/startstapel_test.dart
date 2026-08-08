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
