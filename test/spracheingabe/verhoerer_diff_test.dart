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
