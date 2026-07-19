import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/data/fake_aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('Fake: Batch dedupt Regel-Zeilen wie der DB-Index', () async {
    final gw = FakeAufgabenGateway();
    final r = Aufgabe(
      id: '', titel: 'R', kategorie: 'schutz', faelligAm: DateTime(2026, 10, 31),
      quelle: 'regel', regelKey: 'maeuseschutz_ansetzen', saisonJahr: 2026,
    );
    await gw.speichernBatch([r, r]);
    expect((await gw.alle()).length, 1);
  });

  test('Fake: setzeStatus + loeschen', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'M', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1)));
    final id = (await gw.alle()).single.id;
    await gw.setzeStatus(id, 'erledigt', erledigtAm: DateTime(2026, 8, 1, 12));
    expect((await gw.alle()).single.status, 'erledigt');
    await gw.loeschen(id);
    expect(await gw.alle(), isEmpty);
  });
}
