import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/util/relativ_datum.dart';

void main() {
  final heute = DateTime(2026, 7, 19);
  test('relativGesehen: heute/gestern/vor N Tagen/noch nie', () {
    expect(relativGesehen(DateTime(2026, 7, 19, 23), heute), 'heute');
    expect(relativGesehen(DateTime(2026, 7, 18), heute), 'gestern');
    expect(relativGesehen(DateTime(2026, 7, 12), heute), 'vor 7 Tagen');
    expect(relativGesehen(null, heute), 'noch nie');
  });
  test('relativGesehen: Zukunftsdatum (Uhr verstellt) fällt auf heute zurück', () {
    expect(relativGesehen(DateTime(2026, 7, 25), heute), 'heute');
  });
}
