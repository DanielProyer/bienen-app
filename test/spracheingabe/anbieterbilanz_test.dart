import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/anbieterbilanz.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

SprachErgebnis _e({
  required String anbieter,
  double? quote,
  double? wer,
  String? fehler,
  String modell = 'm',
}) => SprachErgebnis(
  id: '',
  probeId: 'p',
  anbieter: anbieter,
  modell: modell,
  mitWortliste: true,
  trefferQuote: quote,
  wortfehlerrate: wer,
  fehler: fehler,
);

void main() {
  test('ohne Messungen kommt nichts zurück', () {
    expect(anbieterBilanzieren(const []), isEmpty);
  });

  test('mittelt die Trefferquote je Anbieter', () {
    final b = anbieterBilanzieren([
      _e(anbieter: 'infomaniak', quote: 1.0),
      _e(anbieter: 'infomaniak', quote: 0.5),
    ]);
    expect(b, hasLength(1));
    expect(b.first.anbieter, 'infomaniak');
    expect(b.first.messungen, 2);
    expect(b.first.trefferQuoteMittel, closeTo(0.75, 0.001));
  });

  test('gescheiterte Messungen zählen NICHT in den Mittelwert', () {
    // Sonst zoege ein Ausfall die Quote nach unten und saehe aus wie eine
    // schlechte Erkennung — zwei ganz verschiedene Dinge.
    final b = anbieterBilanzieren([
      _e(anbieter: 'elevenlabs', quote: 1.0),
      _e(anbieter: 'elevenlabs', fehler: 'HTTP 400'),
    ]);
    expect(b.first.messungen, 1);
    expect(b.first.fehlschlaege, 1);
    expect(b.first.trefferQuoteMittel, 1.0);
  });

  test('ohne verwertbare Messung ist der Mittelwert null, nicht 0.0', () {
    // 0.0 hiesse "gemessen und ganz schlecht". Nichts gemessen ist etwas
    // anderes, und die Anzeige muss das unterscheiden koennen.
    final b = anbieterBilanzieren([_e(anbieter: 'assemblyai', fehler: 'Zeitüberschreitung')]);
    expect(b.first.messungen, 0);
    expect(b.first.fehlschlaege, 1);
    expect(b.first.trefferQuoteMittel, isNull);
    expect(b.first.wortfehlerMittel, isNull);
  });

  test('die Wortfehlerrate mittelt nur über Messungen, die eine haben', () {
    // Wortkarten haben keine — sie duerfen den Satz-Mittelwert nicht verwaessern.
    final b = anbieterBilanzieren([
      _e(anbieter: 'infomaniak', quote: 1.0, wer: 0.2),
      _e(anbieter: 'infomaniak', quote: 1.0),
    ]);
    expect(b.first.messungen, 2);
    expect(b.first.wortfehlerMittel, closeTo(0.2, 0.001));
  });

  test('sortiert nach Trefferquote, Bestes zuerst; Anbieter ohne Messung ans Ende', () {
    final b = anbieterBilanzieren([
      _e(anbieter: 'schwach', quote: 0.4),
      _e(anbieter: 'stark', quote: 0.9),
      _e(anbieter: 'ohne', fehler: 'kaputt'),
    ]);
    expect(b.map((x) => x.anbieter), ['stark', 'schwach', 'ohne']);
  });

  test('das Modell wird mitgeführt — sonst weiss man nicht, womit gemessen wurde', () {
    final b = anbieterBilanzieren([
      _e(anbieter: 'elevenlabs', quote: 1.0, modell: 'scribe_v2 (ohne Wortliste)'),
    ]);
    expect(b.first.modelle, ['scribe_v2 (ohne Wortliste)']);
  });
}
