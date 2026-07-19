import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/aufgaben/data/fake_aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';

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

  test('Notifier: vorschlagAnnehmen legt je Volk eine Regel-Zeile an', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final regel = kSaisonRegeln.firstWhere((r) => r.key == 'startfuetterung');
    final v = AufgabenVorschlag(
      regel: regel, fensterStart: DateTime(2026, 7, 15), fensterEnde: DateTime(2026, 7, 31),
      faelligAm: DateTime(2026, 7, 31), saisonJahr: 2026,
    );
    await c.read(aufgabenListProvider.notifier).vorschlagAnnehmen(v, volkIds: ['v1', 'v2']);
    final rows = await gw.alle();
    expect(rows.length, 2);
    expect(rows.every((a) => a.regelKey == 'startfuetterung' && a.status == 'offen'), isTrue);
    expect(rows.map((a) => a.volkId).toSet(), {'v1', 'v2'});
  });

  test('Notifier: vorschlagAnnehmen betrieb-Ebene: EINE Zeile, volkIds ignoriert', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final regel = kSaisonRegeln.firstWhere((r) => r.key == 'maeuseschutz_ansetzen');
    final v = AufgabenVorschlag(
      regel: regel, fensterStart: DateTime(2026, 10, 1), fensterEnde: DateTime(2026, 10, 31),
      faelligAm: DateTime(2026, 10, 31), saisonJahr: 2026,
    );
    await c.read(aufgabenListProvider.notifier).vorschlagAnnehmen(v, volkIds: ['v1', 'v2']);
    final rows = await gw.alle();
    expect(rows.single.volkId, isNull);
    expect(rows.single.regelKey, 'maeuseschutz_ansetzen');
    expect(rows.single.status, 'offen');
  });

  test('Notifier: vorschlagUeberspringen legt EINE Zeile ohne volk_id an', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final regel = kSaisonRegeln.firstWhere((r) => r.key == 'sommerbehandlung_1');
    final v = AufgabenVorschlag(
      regel: regel, fensterStart: DateTime(2026, 7, 20), fensterEnde: DateTime(2026, 8, 15),
      faelligAm: DateTime(2026, 8, 15), saisonJahr: 2026,
    );
    await c.read(aufgabenListProvider.notifier).vorschlagUeberspringen(v);
    final rows = await gw.alle();
    expect(rows.single.status, 'uebersprungen');
    expect(rows.single.volkId, isNull);
  });

  test('offeneAufgabenStatsProvider zählt offen + überfällig', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'alt', kategorie: 'sonstiges', faelligAm: DateTime(2020, 1, 1)));
    await gw.speichern(Aufgabe(id: '', titel: 'zukunft', kategorie: 'sonstiges', faelligAm: DateTime(2099, 1, 1)));
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final stats = c.read(offeneAufgabenStatsProvider);
    expect(stats.offen, 2);
    expect(stats.ueberfaellig, 1);
  });

  test('aufgabenFuerVolkProvider: nur offene des Volks', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'a', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1), volkId: 'v1'));
    await gw.speichern(Aufgabe(id: '', titel: 'b', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1), volkId: 'v2'));
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    expect(c.read(aufgabenFuerVolkProvider('v1')).single.titel, 'a');
  });
}
