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
