import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

/// Regression: Eine neu angelegte Königin muss dem Volk zugeordnet werden können.
/// Der Fehler war, dass `koeniginSpeichern` KEINE id zurückgab — ohne die kann
/// der Aufrufer nicht zuordnen, die Königin blieb ein unsichtbarer
/// Register-Eintrag (`volk_id = null`) und die Volk-Sektion zeigte weiter
/// „weisellos". Genau dieser Ablauf wird hier festgenagelt.
void main() {
  late FakeVoelkerGateway gw;

  setUp(() async {
    gw = FakeVoelkerGateway();
    await gw.volkSpeichern(const Volk(id: '', name: 'Primeras'));
  });

  Future<Volk> volk() async => (await gw.voelker()).single;

  test('koeniginSpeichern liefert die vergebene id zurück', () async {
    final gespeichert =
        await gw.koeniginSpeichern(const Koenigin(id: '', kennung: 'Liv'));
    expect(gespeichert.id, isNotEmpty);
    expect(gespeichert.kennung, 'Liv');
  });

  test('anlegen + zuordnen: Volk trägt die Königin, Königin kennt das Volk',
      () async {
    final v = await volk();
    expect(v.koeniginId, isNull, reason: 'Ausgangslage: weisellos');

    final neu = await gw.koeniginSpeichern(const Koenigin(id: '', kennung: 'Liv'));
    await gw.umweiseln(volkId: v.id, neueKoeniginId: neu.id);

    final danach = await volk();
    expect(danach.koeniginId, neu.id);
    expect(danach.koenigin?.kennung, 'Liv',
        reason: 'die Volk-Sektion liest volk.koenigin — die muss gefüllt sein');
    expect((await gw.koeniginnen()).single.volkId, v.id);
  });

  test('ohne Zuordnung bleibt die Königin ein freier Register-Eintrag', () async {
    await gw.koeniginSpeichern(const Koenigin(id: '', kennung: 'Reserve'));
    expect((await gw.koeniginnen()).single.volkId, isNull);
    expect((await volk()).koeniginId, isNull,
        reason: 'Register-Eintrag darf kein Volk verändern');
  });

  test('Löschen einer zugeordneten Königin macht das Volk weisellos', () async {
    final v = await volk();
    final neu = await gw.koeniginSpeichern(const Koenigin(id: '', kennung: 'Liv'));
    await gw.umweiseln(volkId: v.id, neueKoeniginId: neu.id);

    await gw.koeniginLoeschen(neu.id);

    expect(await gw.koeniginnen(), isEmpty);
    final danach = await volk();
    expect(danach.koeniginId, isNull);
    expect(danach.name, 'Primeras', reason: 'übrige Volk-Felder bleiben erhalten');
  });
}
