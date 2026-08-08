/// Ergebnis einer Trefferzählung.
class Trefferbild {
  /// Begriffe aus der Erwartungsliste, die im Transkript vorkommen.
  final List<String> gefunden;

  /// Begriffe, die fehlen — das sind die Verhörer, um die es geht.
  final List<String> fehlend;

  /// Anteil gefundener Begriffe, 0.0 bis 1.0.
  final double quote;

  const Trefferbild({
    required this.gefunden,
    required this.fehlend,
    required this.quote,
  });
}

/// Zählt, wie viele der erwarteten Fachbegriffe im Transkript stehen.
///
/// Das ist das Hauptmass des Erkenner-Vergleichs: Nicht die Gesamtfehlerrate
/// entscheidet über den Nutzen, sondern ob die Fachwörter ankommen. Ein
/// Transkript mit perfektem Fliesstext, in dem „Weiselzellen" fehlt, ist für
/// das Vorbefüllen des Formulars wertlos.
///
/// Bewusst **Teilstring**-Vergleich statt Wortgrenzen: Sagt der Imker
/// „Varroamilben", hat er „Varroa" gesagt — der Erkenner hat es richtig
/// verstanden, auch wenn kein eigenständiges Wort dasteht. Ein strengerer
/// Vergleich würde den Dienst schlechter aussehen lassen, als er ist. Der
/// Nebeneffekt (Satzzeichen am Wortrand stören nicht) ist erwünscht.
///
/// Gross- und Kleinschreibung wird ignoriert, weil die Anbieter
/// unterschiedlich normalisieren und das für die Frage „verstanden oder
/// nicht" belanglos ist.
///
/// Wird später in der App wiederverwendet, um wiederholte Verhörer zu
/// erkennen und in die Korrekturliste des Betriebs zu übernehmen.
Trefferbild zaehleTreffer({
  required String transkript,
  required List<String> erwartet,
}) {
  final heuhaufen = transkript.toLowerCase();
  final gefunden = <String>[];
  final fehlend = <String>[];

  for (final begriff in erwartet) {
    if (heuhaufen.contains(begriff.toLowerCase())) {
      gefunden.add(begriff);
    } else {
      fehlend.add(begriff);
    }
  }

  return Trefferbild(
    gefunden: gefunden,
    fehlend: fehlend,
    // Ohne Erwartungsliste gibt es nichts zu treffen — 0.0 statt NaN.
    quote: erwartet.isEmpty ? 0.0 : gefunden.length / erwartet.length,
  );
}
