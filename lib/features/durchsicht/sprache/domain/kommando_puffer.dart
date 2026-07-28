import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

/// Führt Erkennungsstücke zusammen, bis ein Kommando darin steht.
///
/// Warum: Die Spracherkennung schliesst Satzstücke ab, wann **sie** eine Pause
/// hört — nicht, wann der Satz fachlich fertig ist. „Temperatur zwanzig Grad"
/// kommt deshalb oft als zwei Stücke an: erst „Temperatur", dann „zwanzig
/// Grad". Jedes für sich ergibt kein Kommando — im ersten fehlt die Zahl, im
/// zweiten das Feldwort. Genau das war die Ursache dafür, dass beim Kommando-
/// Mikro fast nichts ankam (2026-07-28).
///
/// Der Puffer hebt deshalb auf, was noch nicht verstanden wurde, und probiert
/// es mit dem nächsten Stück zusammen. Sobald ein Kommando erkannt ist, wird
/// der Rest verworfen — sonst würde ein altes Feldwort später eine fremde Zahl
/// einfangen.
///
/// [maxWoerter] begrenzt, wie viel unverstandener Text mitgeschleppt wird.
/// Ohne die Grenze sammelte sich beliebiges Gerede an und könnte zufällig ein
/// Kommando ergeben.
class KommandoPuffer {
  final SprachKontext kontext;
  final int maxWoerter;
  String _offen = '';

  KommandoPuffer(this.kontext, {this.maxWoerter = 8});

  /// Der noch nicht verstandene Rest — für Anzeige und Tests.
  String get offenerText => _offen;

  /// Nimmt ein neues Erkennungsstück auf und liefert das erkannte Kommando.
  ///
  /// Gibt eine Liste zurück, obwohl [parseKommando] höchstens eines liefert:
  /// Der Aufrufer soll nicht auf `null` prüfen müssen, und mehr als eines pro
  /// Satz bleibt so später nachrüstbar.
  List<SprachKommando> fuettere(String stueck) {
    final zusammen = ('$_offen $stueck').trim();
    if (zusammen.isEmpty) return const [];

    final kommando = parseKommando(zusammen, kontext);
    if (kommando != null) {
      _offen = '';
      return [kommando];
    }

    _offen = _kuerze(zusammen);
    return const [];
  }

  /// Verwirft den offenen Rest — beim Ein- und Ausschalten des Mikros.
  void leeren() => _offen = '';

  String _kuerze(String text) {
    final woerter =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (woerter.length <= maxWoerter) return woerter.join(' ');
    return woerter.sublist(woerter.length - maxWoerter).join(' ');
  }
}
