import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';
import 'package:bienen_app/features/wissen/domain/fuetterung_wissen.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('kFuetterungZweckWissen: jeder Wert löst via wissenVon auf', () {
    for (final key in kFuetterungZweckWissen.values) {
      expect(wissenVon(key), isNotNull, reason: 'Wissens-key fehlt: $key');
    }
  });
  test('kFuetterungZweckWissen: jeder Schlüssel ist ein gültiger Zweck', () {
    for (final k in kFuetterungZweckWissen.keys) {
      expect(Zweck.werte.contains(k), isTrue, reason: 'Unbekannter Zweck: $k');
    }
  });
  test('kFuetterungFutterartWissen: jeder Wert löst via wissenVon auf', () {
    for (final key in kFuetterungFutterartWissen.values) {
      expect(wissenVon(key), isNotNull, reason: 'Wissens-key fehlt: $key');
    }
  });
  test('kFuetterungFutterartWissen: jeder Schlüssel ist eine gültige Futterart', () {
    for (final k in kFuetterungFutterartWissen.keys) {
      expect(Futterart.werte.contains(k), isTrue, reason: 'Unbekannte Futterart: $k');
    }
  });
}
