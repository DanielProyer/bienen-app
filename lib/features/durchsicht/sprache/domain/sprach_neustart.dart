/// Schutzlogik gegen den Endlos-Neustart der Spracherkennung.
///
/// Hintergrund (Fehler vom 2026-07-27): Der Dauer-Modus startet die Erkennung
/// nach jedem `onend` neu, damit man am Bienenstand durchsprechen kann, ohne
/// nachzutippen. Endet die Erkennung aber **sofort** wieder — weil das Mikrofon
/// nicht freigegeben ist, kein Netz besteht oder ein zweiter Erkenner
/// dazwischenfunkt — dreht diese Kette mit voller Geschwindigkeit: `onend` →
/// `start` → `onend` → … Das Mikro kam nicht mehr zur Ruhe.
///
/// Beides hier sind reine Funktionen ohne Browser-Bezug, damit die
/// Entscheidung „darf neu gestartet werden?" prüfbar ist — der Erkenner selbst
/// ist wegen `dart:js_interop` nicht testbar.
library;

/// Fehlercodes der Web Speech API, nach denen ein Neustart sinnlos ist.
///
/// `no-speech` und `aborted` gehören ausdrücklich **nicht** dazu: Eine
/// Sprechpause ist der Normalfall, und `aborted` entsteht bei jedem regulären
/// Stoppen. `network` ebenfalls nicht — am Bienenstand reisst die Verbindung
/// öfter ab, dort ist ein gebremster Neustart richtig.
bool istFatalerFehler(String code) => const {
      'not-allowed', // Nutzer hat das Mikrofon verweigert
      'service-not-allowed', // Browser/Richtlinie verbietet den Dienst
      'audio-capture', // kein Aufnahmegerät vorhanden
    }.contains(code);

/// Begrenzt Neustarts auf [maxVersuche] innerhalb von [fenster].
///
/// Kein Zeitgeber und keine Uhr im Inneren: Die Zeit kommt als Parameter,
/// damit sich Sturzfolgen im Test ohne Warten nachstellen lassen.
class NeustartBremse {
  final int maxVersuche;
  final Duration fenster;
  final List<DateTime> _versuche = [];

  NeustartBremse({this.maxVersuche = 4, this.fenster = const Duration(seconds: 10)});

  /// Meldet einen Neustartwunsch an und sagt, ob er erlaubt ist.
  bool darfNeuStarten(DateTime jetzt) {
    _versuche.removeWhere((t) => jetzt.difference(t) > fenster);
    if (_versuche.length >= maxVersuche) return false;
    _versuche.add(jetzt);
    return true;
  }

  /// Die Erkennung lief lange genug, um als geglückt zu gelten.
  ///
  /// Ohne das würde stundenlanges Diktieren irgendwann grundlos blockiert,
  /// weil sich harmlose Neustarts über den Tag aufaddieren.
  void erfolgreichGelaufen() => _versuche.clear();

  /// Bewusster Neustart durch den Nutzer — Zähler auf null.
  void zuruecksetzen() => _versuche.clear();
}
