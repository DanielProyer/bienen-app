import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';

void main() {
  test('waben leer -> toInsertJson[waben]==null (rückwärtskompatibel)', () {
    final d = Durchsicht(id: '', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 6, 1));
    expect(d.toInsertJson()['waben'], isNull);
  });
  test('waben Roundtrip', () {
    final d = Durchsicht(id: '', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 6, 1),
        waben: const [WabeBeobachtung(inhalte: {'brut'}, koenigin: true)]);
    final j = d.toInsertJson();
    expect((j['waben'] as List).length, 1);
    final back = Durchsicht.fromJson({...j, 'id': 'x'});
    expect(back.waben.single.inhalte, {'brut'});
    expect(back.waben.single.koenigin, isTrue);
  });
  test('fromJson ohne waben -> []', () {
    final d = Durchsicht.fromJson({'id': 'x', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-06-01'});
    expect(d.waben, isEmpty);
  });
}
