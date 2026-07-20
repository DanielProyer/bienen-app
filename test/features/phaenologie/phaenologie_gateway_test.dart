import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/data/fake_phaenologie_gateway.dart';

void main() {
  test('Fake: upsert dedupt je (jahr, anker)', () async {
    final gw = FakePhaenologieGateway();
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.tracht, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14)));
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.tracht, indikatorKey: 'linde', bluehAm: DateTime(2026, 6, 20)));
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'loewenzahn', bluehAm: DateTime(2026, 4, 30)));
    final alle = await gw.alle();
    expect(alle.length, 2); // tracht überschrieben, fruehjahr separat
    final tracht = alle.firstWhere((b) => b.anker == PhaenoAnker.tracht);
    expect(tracht.indikatorKey, 'linde');
  });
}
