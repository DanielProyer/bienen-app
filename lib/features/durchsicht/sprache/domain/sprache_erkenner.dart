abstract class SpracheErkenner {
  bool get verfuegbar;
  Stream<SprachErgebnis> get ergebnisse;
  Stream<ErkennerStatus> get status;
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true});
  Future<void> stoppen();
  void dispose();
}

class SprachErgebnis {
  final String text;
  final bool endgueltig;
  const SprachErgebnis(this.text, {required this.endgueltig});
}

enum ErkennerStatus { idle, hoert, fehler }

enum ErkennerFehler { nichtVerfuegbar, keinMikro, keinNetz, abgebrochen }
