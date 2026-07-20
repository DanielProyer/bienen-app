import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/domain/durchsicht_wissen.dart';

void main() {
  test('jeder Andock-Wert löst auf', () {
    for (final key in kDurchsichtWissen.values) {
      expect(wissenVon(key), isNotNull, reason: key);
    }
  });
  test('jeder Andock-Schlüssel ist ein bekanntes Merkmal', () {
    final bekannt = {...WabeBeobachtung.kWabenInhalte, 'flag_koenigin', 'flag_weiselzelle', 'flag_stifte'};
    for (final k in kDurchsichtWissen.keys) {
      expect(bekannt.contains(k), isTrue, reason: k);
    }
  });
}
