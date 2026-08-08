import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/data/fake_spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

void main() {
  test('erster Verhörer bleibt inaktiv, zweiter schaltet die Regel scharf', () async {
    final g = FakeSpracheingabeGateway();

    final erst = await g.verhoererMelden(
      betriebId: 'b1',
      personId: 'u1',
      falsch: 'weissenzellen',
      richtig: 'Weiselzellen',
      quelle: 'training',
    );
    expect(erst!.treffer, 1);
    expect(erst.aktiv, isFalse, reason: 'ein einzelner Verhörer darf keine Regel sein');

    final zweit = await g.verhoererMelden(
      betriebId: 'b1',
      personId: 'u1',
      falsch: 'Weissenzellen',
      richtig: 'Weiselzellen',
      quelle: 'training',
    );
    expect(zweit!.treffer, 2);
    expect(zweit.aktiv, isTrue);
    expect(g.korrekturen, hasLength(1), reason: 'derselbe Verhörer legt keine zweite Zeile an');
  });

  test('ein Seuchenbegriff wird auch nach vielen Treffern nicht scharf', () async {
    final g = FakeSpracheingabeGateway();
    for (var i = 0; i < 5; i++) {
      await g.verhoererMelden(
        betriebId: 'b1',
        personId: 'u1',
        falsch: 'faulbrot',
        richtig: 'Faulbrut',
        quelle: 'training',
      );
    }
    expect(g.korrekturen.single.treffer, 5);
    expect(g.korrekturen.single.aktiv, isFalse);
  });

  test('nur aktive Karten werden geladen', () async {
    final g = FakeSpracheingabeGateway();
    await g.karteAnlegen(
      const SprachKarte(id: '', art: KartenArt.wort, sollText: 'Varroa', aktiv: true),
    );
    await g.karteAnlegen(
      const SprachKarte(id: '', art: KartenArt.wort, sollText: 'Altlast', aktiv: false),
    );
    final geladen = await g.kartenLaden();
    expect(geladen.map((k) => k.sollText), ['Varroa']);
  });

  test('Ergebnisse werden ihrer Probe zugeordnet', () async {
    final g = FakeSpracheingabeGateway();
    final p = await g.probeAnlegen(
      const SprachProbe(
        id: '',
        personId: 'u1',
        sollText: 'Varroa',
        modus: ProbenModus.drill,
        storagePath: 'b/u/x.webm',
        dauerMs: 1000,
        groesseB: 2048,
      ),
    );
    await g.ergebnisAnlegen(
      SprachErgebnis(
        id: '',
        probeId: p.id,
        anbieter: 'infomaniak',
        mitWortliste: true,
        transkript: 'Varroa',
      ),
    );
    await g.ergebnisAnlegen(
      SprachErgebnis(
        id: '',
        probeId: 'fremd',
        anbieter: 'elevenlabs',
        mitWortliste: true,
        transkript: 'x',
      ),
    );
    final e = await g.ergebnisseZu(p.id);
    expect(e, hasLength(1));
    expect(e.single.anbieter, 'infomaniak');
  });

  test('der Startstapel wird nur einmal angelegt', () async {
    final g = FakeSpracheingabeGateway();
    final erst = await g.startstapelSicherstellen();
    expect(erst, 30);
    final zweit = await g.startstapelSicherstellen();
    expect(zweit, 0, reason: 'ein zweiter Aufruf darf keine Dubletten erzeugen');
    expect((await g.kartenLaden()).length, 30);
  });
}
