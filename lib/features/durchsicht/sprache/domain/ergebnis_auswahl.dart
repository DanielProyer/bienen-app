import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

/// Entscheidet, welche Erkennungsergebnisse tatsächlich neu sind.
///
/// Die Web Speech API füllt bei jedem Ereignis **die gesamte bisherige
/// Sitzung** in `results` — nicht nur das Neue. Wer stumpf über die ganze
/// Liste läuft, liefert jedes bereits abgeschlossene Satzstück bei jedem
/// weiteren Ereignis erneut aus. Genau daran hing der gemeldete Fehler vom
/// 2026-07-28: Aus „schönes Wetter" wurde „schönes schönes schönes wetter",
/// weil der Verbraucher jedes endgültige Ergebnis an den Text anhängt.
///
/// Zwei Sicherungen, weil eine allein zu knapp ist:
///  * `resultIndex` des Ereignisses gibt an, ab wo die neuen Ergebnisse
///    stehen — das ist der vorgesehene Weg.
///  * Zusätzlich wird gemerkt, bis zu welchem Index bereits **endgültige**
///    Ergebnisse geliefert wurden. Manche Browser lassen `resultIndex` im
///    Dauer-Modus auf 0 stehen; dann trägt dieser Merker.
///
/// Reine Logik, damit sie ohne Browser prüfbar ist — wie [NeustartBremse].
class ErgebnisAuswahl {
  /// Index, ab dem endgültige Ergebnisse noch nicht ausgeliefert wurden.
  int _naechsterFinal = 0;

  /// Liefert die Ergebnisse, die der Verbraucher noch nicht gesehen hat.
  ///
  /// [resultIndex] ist `event.resultIndex` der Web Speech API, [ergebnisse]
  /// der Inhalt von `event.results` in Reihenfolge.
  List<SprachErgebnis> auswaehlen({
    required int resultIndex,
    required List<({String text, bool endgueltig})> ergebnisse,
  }) {
    final heraus = <SprachErgebnis>[];
    final start = resultIndex.clamp(0, ergebnisse.length);

    for (var i = start; i < ergebnisse.length; i++) {
      final e = ergebnisse[i];
      if (e.text.trim().isEmpty) continue;

      if (e.endgueltig) {
        // Schon geliefert — ein zweites Mal würde den Text verdoppeln.
        if (i < _naechsterFinal) continue;
        _naechsterFinal = i + 1;
      }
      heraus.add(SprachErgebnis(e.text, endgueltig: e.endgueltig));
    }
    return heraus;
  }

  /// Nach einem Neustart der Erkennung beginnt `results` wieder bei 0.
  ///
  /// Ohne diesen Aufruf hielte der Merker den ersten Satz nach jeder
  /// Sprechpause für bereits ausgeliefert — er käme nie an.
  void zuruecksetzen() => _naechsterFinal = 0;
}
