import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/bewertung_wissen.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';

void main() {
  test('jeder Wissens-key der Andock-Map löst via wissenVon auf', () {
    for (final entry in kBewertungAchseWissen.entries) {
      expect(wissenVon(entry.value), isNotNull,
          reason: 'Achse ${entry.key} → Wissen ${entry.value} fehlt');
    }
  });

  test('jeder Andock-Schlüssel ist eine echte Bewertungs-Achse', () {
    final achsen = kBewertungsAchsen.map((a) => a.key).toSet();
    for (final key in kBewertungAchseWissen.keys) {
      expect(achsen.contains(key), isTrue,
          reason: 'Andock-Schlüssel $key ist keine Bewertungs-Achse');
    }
  });
}
