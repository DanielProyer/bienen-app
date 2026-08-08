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
