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
  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async => _st.add(ErkennerStatus.hoert);
  @override
  Future<void> stoppen() async => _st.add(ErkennerStatus.idle);
  @override
  void dispose() { _erg.close(); _st.close(); }
  /// Test-Helfer: simuliert ein Erkennungs-Ergebnis.
  void sende(String text, {bool endgueltig = true}) => _erg.add(SprachErgebnis(text, endgueltig: endgueltig));
}
