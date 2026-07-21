import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

/// Nicht-Web-Ziele (VM/Tests): die dart:js_interop-Kapsel baut dort nicht,
/// also ein No-op-Erkenner mit verfuegbar == false → SprachMikro rendert nichts, Tippen bleibt.
SpracheErkenner spracheErkennerErstellen() => const NichtVerfuegbarErkenner();

class NichtVerfuegbarErkenner implements SpracheErkenner {
  const NichtVerfuegbarErkenner();
  @override
  bool get verfuegbar => false;
  @override
  Stream<SprachErgebnis> get ergebnisse => const Stream<SprachErgebnis>.empty();
  @override
  Stream<ErkennerStatus> get status => const Stream<ErkennerStatus>.empty();
  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async {}
  @override
  Future<void> stoppen() async {}
  @override
  void dispose() {}
}
