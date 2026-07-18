import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';

void main() {
  Future<int> erfasse(FakeBehandlungGateway g, {required List<String> volkIds, String anwendungsart = 'dispenser_verdunster', num? menge = 40, String? einheit = 'ml', String? material}) =>
      g.behandlungErfassen(volkIds: volkIds, datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'ameisensaeure',
          anwendungsart: anwendungsart, verantwortlichePerson: 'Tester', praeparat: 'FORMIVAR',
          mengeProVolk: menge, einheit: einheit, materialId: material);

  test('Sammelbehandlung: distinct Voelker -> je EINE Zeile, Lager einmal je Volk abgebucht', () async {
    final g = FakeBehandlungGateway()..lagerBestand['m1'] = 1000;
    final n = await erfasse(g, volkIds: ['v1', 'v1', 'v2'], material: 'm1'); // Duplikat v1
    expect(n, 2); // v1 + v2, nicht 3
    expect((await g.behandlungenFuerVolk('v1')).length, 1);
    expect((await g.behandlungenFuerVolk('v2')).length, 1);
    expect(g.lagerBestand['m1'], 1000 - 40 * 2); // 920
  });

  test('BA031 bei leerem Array', () async {
    final g = FakeBehandlungGateway();
    expect(() => erfasse(g, volkIds: []), throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA031')));
  });

  test('BA030 wenn Praeparat bei chemischer Anwendung fehlt', () async {
    final g = FakeBehandlungGateway();
    expect(
      () => g.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'thymol',
          anwendungsart: 'traeufeln', verantwortlichePerson: 'T', praeparat: '', mengeProVolk: 5, einheit: 'g'),
      throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA030')),
    );
  });

  test('BA033 chemisch ohne Menge', () async {
    final g = FakeBehandlungGateway();
    expect(() => erfasse(g, volkIds: ['v1'], menge: null),
        throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA033')));
  });

  test('Biotechnik ohne Praeparat/Menge erlaubt', () async {
    final g = FakeBehandlungGateway();
    final n = await g.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 6, 1),
        wirkstoff: 'sonstige', anwendungsart: 'biotechnik', verantwortlichePerson: 'Tester');
    expect(n, 1);
  });

  test('Storno ist terminal (BA034 bei zweitem Storno)', () async {
    final g = FakeBehandlungGateway();
    await erfasse(g, volkIds: ['v1']);
    final id = (await g.behandlungenFuerVolk('v1')).first.id;
    await g.behandlungStornieren(id, 'Fehler');
    expect((await g.behandlungenFuerVolk('v1')).first.isStorniert, isTrue);
    expect(() => g.behandlungStornieren(id, 'nochmal'),
        throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA034')));
  });
}
