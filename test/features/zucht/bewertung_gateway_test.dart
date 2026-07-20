import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/data/fake_bewertung_gateway.dart';

void main() {
  test('Fake: speichern (insert+update) + alle + loeschen', () async {
    final gw = FakeBewertungGateway();
    await gw.speichern(VolkBewertung(id: '', volkId: 'v1', bewertetAm: DateTime(2026, 6, 1),
        sanftmut: 3, wabensitz: 3, schwarmtraegheit: 3, brutbild: 3, volksstaerke: 3, gesundheit: 3));
    var alle = await gw.alle();
    expect(alle.length, 1);
    final id = alle.first.id;
    await gw.speichern(VolkBewertung(id: id, volkId: 'v1', bewertetAm: DateTime(2026, 6, 1),
        sanftmut: 4, wabensitz: 3, schwarmtraegheit: 3, brutbild: 3, volksstaerke: 3, gesundheit: 3));
    alle = await gw.alle();
    expect(alle.length, 1);
    expect(alle.first.sanftmut, 4);
    await gw.loeschen(id);
    expect((await gw.alle()), isEmpty);
  });
}
