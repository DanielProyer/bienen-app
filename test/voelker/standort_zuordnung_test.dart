import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

/// Regression: Ein neu angelegter Standort muss dem Volk zugeordnet werden
/// können. Der Fehler war, dass `standortSpeichern` KEINE id zurückgab — ohne
/// die kann der Aufrufer nicht zuordnen, der Stand blieb ein unsichtbarer
/// Stammdaten-Eintrag und die Volk-Sektion zeigte weiter „kein Standort
/// zugeordnet". Genau dieser Ablauf wird hier festgenagelt — inklusive der
/// Zusicherung, dass das Zuordnen und das Löschen KEINE anderen Volk-Felder
/// verlieren (dafür gibt es `Volk.copyWith`).
void main() {
  late FakeVoelkerGateway gw;

  /// Ein Volk mit gefüllten Nebenfeldern — genau die fielen früher beim
  /// handgebauten Konstruktor-Aufruf still heraus.
  final vollesVolk = Volk(
    id: '',
    name: 'Primeras',
    beutentyp: 'Dadant Blatt',
    zargen: 2,
    brutwaben: 11,
    bioStatus: 'umstellung',
    gesundheitsstatus: 'unauffaellig',
    einweiselungAm: DateTime(2026, 5, 12),
    herkunft: 'Ableger Muster',
    notes: 'sanftmütig',
    sortOrder: 7,
  );

  setUp(() async {
    gw = FakeVoelkerGateway();
    await gw.volkSpeichern(vollesVolk);
  });

  Future<Volk> volk() async => (await gw.voelker()).single;

  void erwarteNebenfelderIntakt(Volk v) {
    expect(v.name, 'Primeras');
    expect(v.beutentyp, 'Dadant Blatt');
    expect(v.zargen, 2);
    expect(v.brutwaben, 11);
    expect(v.bioStatus, 'umstellung');
    expect(v.einweiselungAm, DateTime(2026, 5, 12));
    expect(v.herkunft, 'Ableger Muster');
    expect(v.notes, 'sanftmütig');
    expect(v.sortOrder, 7);
  }

  test('standortSpeichern liefert die vergebene id zurück', () async {
    final gespeichert = await gw.standortSpeichern(
        const Standort(id: '', name: 'Maiensäss', amtlicheStandnummer: 'GR-1234'));
    expect(gespeichert.id, isNotEmpty);
    expect(gespeichert.name, 'Maiensäss');
    expect(gespeichert.amtlicheStandnummer, 'GR-1234');
  });

  test('anlegen + zuordnen: Volk trägt den Standort', () async {
    final v = await volk();
    expect(v.standortId, isNull, reason: 'Ausgangslage: ohne Stand');

    final neu = await gw.standortSpeichern(const Standort(id: '', name: 'Maiensäss'));
    await gw.volkSpeichern(v.copyWith(standortId: neu.id));

    final danach = await volk();
    expect(danach.standortId, neu.id);
    expect(danach.standort?.name, 'Maiensäss',
        reason: 'die Volk-Sektion liest volk.standort — die muss gefüllt sein');
    erwarteNebenfelderIntakt(danach);
  });

  test('ohne Zuordnung bleibt der Standort ein freier Stammdaten-Eintrag',
      () async {
    await gw.standortSpeichern(const Standort(id: '', name: 'Reserve'));
    expect((await gw.standorte()).single.name, 'Reserve');
    expect((await volk()).standortId, isNull,
        reason: 'ein freier Stand darf kein Volk verändern');
  });

  test('Löschen eines zugeordneten Standorts macht das Volk standortlos — '
      'ohne andere Volk-Felder zu verlieren', () async {
    final v = await volk();
    final neu = await gw.standortSpeichern(const Standort(id: '', name: 'Maiensäss'));
    await gw.volkSpeichern(v.copyWith(standortId: neu.id));

    await gw.standortLoeschen(neu.id);

    expect(await gw.standorte(), isEmpty);
    final danach = await volk();
    expect(danach.standortId, isNull);
    expect(danach.standort, isNull);
    erwarteNebenfelderIntakt(danach);
  });

  test('copyWith ohne Argumente ändert nichts', () async {
    final v = await volk();
    final kopie = v.copyWith();
    expect(kopie.id, v.id);
    expect(kopie.standortId, v.standortId);
    erwarteNebenfelderIntakt(kopie);
  });
}
