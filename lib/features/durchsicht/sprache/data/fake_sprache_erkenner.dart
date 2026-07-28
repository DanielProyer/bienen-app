import 'dart:async';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

class FakeSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  @override
  bool verfuegbar = true;
  @override
  Stream<SprachErgebnis> get ergebnisse => _erg.stream;
  @override
  Stream<ErkennerStatus> get status => _st.stream;
  /// Test-Protokoll: hält die Aufrufreihenfolge fest.
  ///
  /// Nötig, um zu prüfen, dass beim Mikro-Wechsel wirklich erst gestoppt und
  /// dann gestartet wird — sonst liefen zwei Erkenner parallel (Mikro-Loop).
  final List<String> aufrufe = [];

  /// Womit zuletzt gestartet wurde.
  ///
  /// Kommandos brauchen den Einzelsatz-Modus (`false`), Diktate den Dauer-Modus
  /// — ohne diese Unterscheidung lief das Kommando-Mikro nach jeder Sprechpause
  /// wieder an.
  bool? zuletztKontinuierlich;

  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async {
    aufrufe.add('starten');
    zuletztKontinuierlich = kontinuierlich;
    _st.add(ErkennerStatus.hoert);
  }

  @override
  Future<void> stoppen() async {
    aufrufe.add('stoppen');
    _st.add(ErkennerStatus.idle);
  }
  @override
  void dispose() { _erg.close(); _st.close(); }
  /// Test-Helfer: simuliert, dass die Erkennung von selbst endet.
  void meldeIdle() => _st.add(ErkennerStatus.idle);

  /// Test-Helfer: simuliert ein Erkennungs-Ergebnis.
  void sende(String text, {bool endgueltig = true}) => _erg.add(SprachErgebnis(text, endgueltig: endgueltig));
}
