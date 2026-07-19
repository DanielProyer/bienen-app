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
  test('relativGesehen: DST-Umstellungen (CH) verfälschen die Tagesdifferenz nicht', () {
    // Frühjahrs-Umstellung 29.03.2026
    expect(relativGesehen(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 'vor 2 Tagen');
    // Herbst-Umstellung 25.10.2026
    expect(relativGesehen(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 'vor 2 Tagen');
  });
}
