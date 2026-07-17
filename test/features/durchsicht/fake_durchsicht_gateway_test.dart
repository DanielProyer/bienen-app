import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/data/fake_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

Durchsicht _d(String id, String volk, String datum) =>
    Durchsicht(id: id, volkId: volk, durchgefuehrtAm: DateTime.parse(datum));

void main() {
  test('fuerVolk absteigend nach Datum', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(_d('', 'v1', '2026-05-01'));
    await gw.speichern(_d('', 'v1', '2026-06-01'));
    await gw.speichern(_d('', 'v2', '2026-05-15'));
    final list = await gw.fuerVolk('v1');
    expect(list.length, 2);
    expect(list.first.durchgefuehrtAm, DateTime.parse('2026-06-01'));
  });

  test('letzteJeVolk = neueste je Volk', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(_d('', 'v1', '2026-05-01'));
    await gw.speichern(_d('', 'v1', '2026-06-01'));
    await gw.speichern(_d('', 'v2', '2026-05-15'));
    final letzte = await gw.letzteJeVolk();
    expect(letzte.length, 2);
    expect(letzte.firstWhere((d) => d.volkId == 'v1').durchgefuehrtAm,
        DateTime.parse('2026-06-01'));
  });

  test('loeschen entfernt Zeile + Fotos', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(Durchsicht(
        id: 'd1', volkId: 'v1', durchgefuehrtAm: DateTime.parse('2026-05-01'),
        fotoUrls: const ['b/v1/foto_1.jpg']));
    final d = (await gw.fuerVolk('v1')).first;
    await gw.loeschen(d);
    expect(await gw.fuerVolk('v1'), isEmpty);
    expect(gw.entfernteFotos, ['b/v1/foto_1.jpg']);
  });
}
