import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/data/fake_vermehrung_gateway.dart';

void main() {
  test('Fake: speichern + alle + jungvolkVerknuepfen + loeschen', () async {
    final gw = FakeVermehrungGateway();
    await gw.speichern(VermehrungsEreignis(
        id: '', methode: 'brutableger', erstelltAm: DateTime(2026, 6, 5), stammvolkId: 'v1'));
    var alle = await gw.alle();
    expect(alle.length, 1);
    final id = alle.first.id;
    await gw.jungvolkVerknuepfen(id, 'j1');
    alle = await gw.alle();
    expect(alle.first.jungvolkId, 'j1');
    await gw.loeschen(id);
    expect((await gw.alle()), isEmpty);
  });
}
