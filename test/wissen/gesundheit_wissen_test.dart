import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';
import 'package:bienen_app/features/wissen/domain/gesundheit_wissen.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('kKrankheitWissen: jeder Wert löst via wissenVon auf', () {
    for (final key in kKrankheitWissen.values) {
      expect(wissenVon(key), isNotNull, reason: 'Wissens-key fehlt: $key');
    }
  });
  test('kKrankheitWissen: jeder Schlüssel ist ein gültiger Krankheit-Key', () {
    for (final k in kKrankheitWissen.keys) {
      expect(krankheitKeys.contains(k), isTrue, reason: 'Unbekannter Krankheit-Key: $k');
    }
  });
}
