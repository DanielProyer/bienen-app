import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme.dart';

/// Auf der VM (Tests, Analyse) gibt es kein Mikrofon. Der Stub wirft beim
/// BENUTZEN, nicht beim Erzeugen — so bleibt jeder Test uebersetzbar, der die
/// Klasse nur referenziert, und ein versehentlicher Aufruf faellt sofort auf.
SprachAufnahme aufnahmeErzeugen() => _StubAufnahme();

class _StubAufnahme implements SprachAufnahme {
  Never _nein() => throw UnsupportedError(
      'Tonaufnahme gibt es nur im Browser (dart.library.js_interop).');

  @override
  Future<void> starten() => _nein();

  @override
  Future<Tonaufnahme> beenden() => _nein();

  @override
  void abbrechen() => _nein();
}
