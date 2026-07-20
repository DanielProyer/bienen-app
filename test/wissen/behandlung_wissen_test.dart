import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/wissen/domain/behandlung_wissen.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('kVarroaMethodeWissen: jeder Wert löst via wissenVon auf', () {
    for (final key in kVarroaMethodeWissen.values) {
      expect(wissenVon(key), isNotNull, reason: 'Wissens-key fehlt: $key');
    }
  });
  test('kVarroaMethodeWissen: jeder Schlüssel ist eine gültige Methode', () {
    const methoden = {'gemuell', 'puderzucker', 'auswaschung'};
    for (final k in kVarroaMethodeWissen.keys) {
      expect(methoden.contains(k), isTrue, reason: 'Unbekannte Methode: $k');
    }
  });
  test('kBehandlungWirkstoffWissen: jeder Wert löst via wissenVon auf', () {
    for (final key in kBehandlungWirkstoffWissen.values) {
      expect(wissenVon(key), isNotNull, reason: 'Wissens-key fehlt: $key');
    }
  });
  test('kBehandlungWirkstoffWissen: jeder Schlüssel ist ein gültiger Wirkstoff', () {
    for (final k in kBehandlungWirkstoffWissen.keys) {
      expect(Wirkstoff.werte.contains(k), isTrue, reason: 'Unbekannter Wirkstoff: $k');
    }
  });
}
