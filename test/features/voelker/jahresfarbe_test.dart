import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';

void main() {
  test('5er-Zyklus ueber die Endziffer', () {
    expect(jahresfarbe(2026), Jahresfarbe.weiss); // 1/6
    expect(jahresfarbe(2027), Jahresfarbe.gelb); // 2/7
    expect(jahresfarbe(2028), Jahresfarbe.rot); // 3/8
    expect(jahresfarbe(2029), Jahresfarbe.gruen); // 4/9
    expect(jahresfarbe(2030), Jahresfarbe.blau); // 5/0
    expect(jahresfarbe(2021), Jahresfarbe.weiss);
    expect(jahresfarbe(2025), Jahresfarbe.blau);
  });
}
