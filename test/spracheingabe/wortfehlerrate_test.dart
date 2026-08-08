import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart';

void main() {
  test('gleicher Text ergibt null Fehler', () {
    expect(wortfehlerrate(soll: 'Königin auf Wabe acht', ist: 'Königin auf Wabe acht'), 0.0);
  });

  test('ein falsches Wort von vieren ergibt ein Viertel', () {
    expect(wortfehlerrate(soll: 'Königin auf Wabe acht', ist: 'Königin auf Wabe achtzig'),
        closeTo(0.25, 0.001));
  });

  test('Gross-/Kleinschreibung und Satzzeichen zählen nicht', () {
    expect(wortfehlerrate(soll: 'Keine Weiselzellen, alles ruhig.', ist: 'keine weiselzellen alles ruhig'),
        0.0);
  });

  test('fehlendes Wort zählt als Fehler', () {
    expect(wortfehlerrate(soll: 'Brut in allen Stadien', ist: 'Brut in Stadien'),
        closeTo(0.25, 0.001));
  });

  test('zusätzlich erfundenes Wort zählt als Fehler', () {
    expect(wortfehlerrate(soll: 'Brut in allen Stadien', ist: 'Brut in allen frischen Stadien'),
        closeTo(0.25, 0.001));
  });

  test('leeres Ist-Transkript ergibt volle Fehlerrate', () {
    expect(wortfehlerrate(soll: 'Königin gesehen', ist: ''), 1.0);
  });

  test('leerer Soll-Text ergibt null statt Division durch null', () {
    expect(wortfehlerrate(soll: '', ist: 'irgendwas'), 0.0);
  });

  test('mehr erfundene Wörter als Soll-Wörter ergibt über 1.0 und wird NICHT gekappt', () {
    // Genau der Fall, den Whisper bei Stille produziert. Eine gekappte Zahl
    // wuerde ihn wie einen gewoehnlichen Fehlschlag aussehen lassen.
    final r = wortfehlerrate(soll: 'Varroa', ist: 'ich habe heute nichts gesagt aber trotzdem');
    expect(r, greaterThan(1.0));
  });
}
