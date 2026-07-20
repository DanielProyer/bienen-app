import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/einstellungen/domain/winterfutter_warnung.dart';

void main() {
  test('unter 20 kg = BGD-Warnung', () {
    expect(unterBgdMinimum(19.9), isTrue);
    expect(unterBgdMinimum(20), isFalse);
    expect(unterBgdMinimum(22), isFalse);
  });
}
