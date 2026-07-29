import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/fachwort_treffer.dart';

void main() {
  test('findet Begriffe unabhängig von Gross- und Kleinschreibung', () {
    final t = zaehleTreffer(
      transkript: 'die weiselzellen sind offen, fünf Milben gefunden',
      erwartet: ['Weiselzellen', 'Milben', 'Schwarmtrieb'],
    );
    expect(t.gefunden, ['Weiselzellen', 'Milben']);
    expect(t.fehlend, ['Schwarmtrieb']);
    expect(t.quote, closeTo(2 / 3, 0.001));
  });

  test('findet Begriffe auch als Teil eines zusammengesetzten Wortes', () {
    // "Varroamilben" enthält "Varroa" — das zählt als Treffer, denn der Imker
    // hat den Begriff gesagt und der Erkenner hat ihn verstanden.
    final t = zaehleTreffer(transkript: 'Varroamilben auf der Windel', erwartet: ['Varroa']);
    expect(t.gefunden, ['Varroa']);
    expect(t.fehlend, isEmpty);
  });

  test('zählt einen Begriff nur einmal, auch bei Mehrfachnennung', () {
    final t = zaehleTreffer(transkript: 'Milben Milben Milben', erwartet: ['Milben']);
    expect(t.gefunden, ['Milben']);
    expect(t.quote, 1.0);
  });

  test('leeres Transkript ergibt Quote null statt Division durch null', () {
    final t = zaehleTreffer(transkript: '', erwartet: ['Milben']);
    expect(t.gefunden, isEmpty);
    expect(t.fehlend, ['Milben']);
    expect(t.quote, 0.0);
  });

  test('leere Erwartungsliste ergibt Quote null und stürzt nicht ab', () {
    final t = zaehleTreffer(transkript: 'irgendetwas', erwartet: []);
    expect(t.gefunden, isEmpty);
    expect(t.fehlend, isEmpty);
    expect(t.quote, 0.0);
  });

  test('ignoriert Satzzeichen am Wortrand', () {
    final t = zaehleTreffer(transkript: 'kein Schwarmtrieb, alles ruhig.', erwartet: ['Schwarmtrieb']);
    expect(t.gefunden, ['Schwarmtrieb']);
  });

  test('der Feldtest-Verhörer zählt als Fehltreffer', () {
    // Genau der Fall aus dem echten Feldtest: der Erkenner schrieb
    // "weissenzellen". Das darf NICHT als Treffer durchgehen, sonst misst der
    // Vergleich sich selbst schön.
    final t = zaehleTreffer(
      transkript: 'die weissenzellen sind zu, fünf Minuten pro Tag',
      erwartet: ['Weiselzellen', 'Milben'],
    );
    expect(t.gefunden, isEmpty);
    expect(t.fehlend, ['Weiselzellen', 'Milben']);
    expect(t.quote, 0.0);
  });
}
