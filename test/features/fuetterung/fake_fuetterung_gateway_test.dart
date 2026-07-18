import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';

Future<int> erfasse(FakeFuetterungGateway g, {required List<String> volkIds, num menge = 5, String zweck = 'auffuetterung', String? material}) =>
    g.fuetterungErfassen(volkIds: volkIds, durchgefuehrtAm: DateTime(2026, 8, 1), zweck: zweck,
        futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: menge, materialId: material);

void main() {
  test('Sammelfütterung: distinct Völker -> je 1 Zeile, Lager je Volk abgebucht', () async {
    final g = FakeFuetterungGateway()..lagerBestand['m1'] = 100;
    final n = await erfasse(g, volkIds: ['v1', 'v1', 'v2'], material: 'm1'); // Duplikat v1
    expect(n, 2);
    expect((await g.fuetterungenFuerVolk('v1')).length, 1);
    expect((await g.fuetterungenFuerVolk('v2')).length, 1);
    expect(g.lagerBestand['m1'], 100 - 5 * 2); // 90
  });

  test('BA041 bei leerem Array', () async {
    final g = FakeFuetterungGateway();
    expect(() => erfasse(g, volkIds: []),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA041')));
  });

  test('BA040 bei ungültigem Zweck / Menge <= 0', () async {
    final g = FakeFuetterungGateway();
    expect(() => erfasse(g, volkIds: ['v1'], zweck: 'quatsch'),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
    expect(() => erfasse(g, volkIds: ['v1'], menge: 0),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
  });

  test('Storno ist terminal (BA040 bei zweitem Storno)', () async {
    final g = FakeFuetterungGateway();
    await erfasse(g, volkIds: ['v1']);
    final id = (await g.fuetterungenFuerVolk('v1')).first.id;
    await g.fuetterungStornieren(id, 'Fehler');
    expect((await g.fuetterungenFuerVolk('v1')).first.isStorniert, isTrue);
    expect(() => g.fuetterungStornieren(id, 'nochmal'),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
  });
}
