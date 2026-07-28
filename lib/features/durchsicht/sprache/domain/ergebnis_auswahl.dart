/// Was ein Erkennungs-Ereignis an Neuem gebracht hat.
typedef ErgebnisZuwachs = ({
  /// Der endgültige Text, der seit dem letzten Ereignis dazugekommen ist —
  /// `null`, wenn nichts Neues abgeschlossen wurde.
  String? neuerEndtext,

  /// Der aktuelle vorläufige Text (Live-Anzeige unter dem Mikro).
  String interim,
});

/// Entscheidet, was an einem Erkennungs-Ereignis wirklich neu ist.
///
/// Die Web Speech API füllt bei jedem Ereignis **die gesamte laufende Sitzung**
/// in `results`, nicht nur den Zuwachs. Wer stumpf alles ausliefert, hängt
/// fertige Satzstücke immer wieder an — daher „schönes schönes schönes wetter".
///
/// Der erste Anlauf verglich Indizes (`event.resultIndex` plus ein Merker, bis
/// wohin geliefert wurde). Das setzt voraus, dass man das Neustart-Verhalten
/// des Browsers genau kennt: Im Dauer-Modus beginnt nach jeder Sprechpause eine
/// neue Sitzung mit Index 0. Traf der Merker diesen Moment nicht, galt der
/// erste Satz des neuen Laufs als „schon geliefert" und verschwand — genau das
/// zweite gemeldete Symptom („nur schönes wird übernommen").
///
/// Deshalb jetzt **ohne Indizes**: Verfolgt wird der zusammengesetzte
/// endgültige Text. Gemeldet wird nur, was hinten dazugekommen ist. Passt der
/// neue Text nicht mehr zum bisherigen (weil eine neue Sitzung begann), gilt er
/// vollständig als neu. Das ist unabhängig davon, wie der Browser zählt.
///
/// Reine Logik, ohne Browser prüfbar — wie die Neustart-Bremse.
class ErgebnisAuswahl {
  /// Der endgültige Text, der bereits gemeldet wurde.
  String _gemeldet = '';

  ErgebnisZuwachs verarbeite(
      List<({String text, bool endgueltig})> ergebnisse) {
    final endgueltig = _fuegeZusammen(ergebnisse.where((e) => e.endgueltig));
    final interim = _fuegeZusammen(ergebnisse.where((e) => !e.endgueltig));

    if (endgueltig.isEmpty || endgueltig == _gemeldet) {
      return (neuerEndtext: null, interim: interim);
    }

    // Regelfall: Der Text ist hinten gewachsen — nur den Zuwachs melden.
    if (endgueltig.startsWith(_gemeldet)) {
      final zuwachs = endgueltig.substring(_gemeldet.length).trim();
      _gemeldet = endgueltig;
      return (
        neuerEndtext: zuwachs.isEmpty ? null : zuwachs,
        interim: interim
      );
    }

    // Der Text passt nicht mehr zum bisherigen: Die Erkennung wurde neu
    // gestartet und zählt von vorn. Dann ist alles davon neu.
    _gemeldet = endgueltig;
    return (neuerEndtext: endgueltig, interim: interim);
  }

  /// Beginnt eine frische Sitzung — etwa wenn der Nutzer das Mikro neu
  /// einschaltet und derselbe Satz erneut gelten soll.
  void zuruecksetzen() => _gemeldet = '';

  String _fuegeZusammen(Iterable<({String text, bool endgueltig})> teile) =>
      teile.map((t) => t.text.trim()).where((t) => t.isNotEmpty).join(' ');
}
