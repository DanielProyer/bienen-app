import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';

void main() {
  test('fromJson/toUpsertJson: nur 4 Felder, kein betrieb_id/id', () {
    final b = PhaenoBeobachtung.fromJson({
      'id': 'x', 'betrieb_id': 'b1', 'jahr': 2026, 'anker': 'tracht',
      'indikator_key': 'alpenrose', 'blueh_am': '2026-06-14',
    });
    expect(b.anker, PhaenoAnker.tracht);
    expect(b.bluehAm, DateTime(2026, 6, 14));
    final j = b.toUpsertJson();
    expect(j.keys.toSet(), {'jahr', 'anker', 'indikator_key', 'blueh_am'});
    expect(j['anker'], 'tracht');
    expect(j['blueh_am'], '2026-06-14');
  });

  test('toUpsertJson: anker-Guard (tracht-Key auf fruehjahr-Anker -> AssertionError)', () {
    final falsch = PhaenoBeobachtung(
        jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14));
    expect(() => falsch.toUpsertJson(), throwsA(isA<AssertionError>()));
  });
}
