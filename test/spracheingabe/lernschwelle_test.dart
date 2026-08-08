import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';

void main() {
  test('ein einzelner Verhörer wird KEINE Regel', () {
    expect(darfRegelWerden(treffer: 1, falsch: 'weissenzellen', richtig: 'Weiselzellen'),
        isFalse);
  });

  test('ab dem zweiten Mal wird er zur Regel', () {
    expect(darfRegelWerden(treffer: 2, falsch: 'weissenzellen', richtig: 'Weiselzellen'),
        isTrue);
  });

  test('Seuchenbegriffe werden nie zur Regel, egal wie oft', () {
    for (final s in ['Faulbrut', 'Sauerbrut', 'Nosema']) {
      expect(darfRegelWerden(treffer: 99, falsch: 'egal', richtig: s), isFalse, reason: s);
    }
  });

  test('Alltagswörter mit Sonderbedeutung ebenfalls nicht', () {
    for (final s in ['Beute', 'Windel', 'Stifte', 'Schied']) {
      expect(darfRegelWerden(treffer: 99, falsch: 'egal', richtig: s), isFalse, reason: s);
    }
  });

  test('ein gesperrter Begriff darf auch nicht die QUELLE einer Regel sein', () {
    // Sonst wuerde die Regel "faulbrut -> irgendetwas" jeden echt gesagten
    // Seuchenbegriff still aus dem Transkript schreiben — die Umkehrung genau
    // der Gefahr, wegen der die Liste existiert.
    expect(darfRegelWerden(treffer: 99, falsch: 'Faulbrut', richtig: 'Faulbaum'), isFalse);
    expect(darfRegelWerden(treffer: 99, falsch: 'beute', richtig: 'baute'), isFalse);
  });

  test('die Sperre greift unabhängig von der Schreibweise', () {
    expect(darfRegelWerden(treffer: 99, falsch: 'egal', richtig: 'faulbrut'), isFalse);
    expect(darfRegelWerden(treffer: 99, falsch: 'egal', richtig: '  FAULBRUT  '), isFalse);
    expect(darfRegelWerden(treffer: 99, falsch: '  FAULBRUT  ', richtig: 'egal'), isFalse);
  });

  test('leeres Zielwort wird nie zur Regel', () {
    expect(darfRegelWerden(treffer: 99, falsch: 'etwas', richtig: '   '), isFalse);
  });

  test('leere Quelle wird nie zur Regel', () {
    expect(darfRegelWerden(treffer: 99, falsch: '   ', richtig: 'Weiselzellen'), isFalse);
  });
}
