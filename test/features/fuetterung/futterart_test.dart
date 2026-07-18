import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

void main() {
  test('Futterart-Werte haben alle ein Label', () {
    for (final w in Futterart.werte) {
      expect(Futterart.labels[w], isNotNull, reason: w);
    }
    expect(Futterart.werte, contains('honig'));
    expect(Futterart.werte, isNot(contains('eigener_honig')));
  });
  test('Zweck-Werte haben alle ein Label', () {
    for (final w in Zweck.werte) {
      expect(Zweck.labels[w], isNotNull, reason: w);
    }
    expect(Zweck.werte, containsAll(['auffuetterung', 'reizfuetterung', 'notfuetterung']));
  });
}
