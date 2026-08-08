import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Wie eine Karte bisher gelaufen ist.
class Kartenbilanz {
  final int versuche;
  final int treffer;
  const Kartenbilanz({required this.versuche, required this.treffer});

  /// 0.0 bis 1.0; ohne Versuch gilt sie als ungeuebt, nicht als schlecht.
  double get quote => versuche == 0 ? 0.0 : treffer / versuche;
}

/// Waehlt die naechste Uebungskarte.
///
/// Reihenfolge der Kriterien:
///  1. **Noch nie geuebt** kommt zuerst — was man nie gesprochen hat, ist die
///     groesste Wissensluecke.
///  2. Dann die **schlechteste Trefferquote** — geuebt wird, was klemmt, nicht
///     was ohnehin sitzt.
///  3. Bei gleicher Quote die **seltener geuebte**.
///
/// Die zuletzt gesprochene Karte wird uebersprungen, solange es eine Alternative
/// gibt: Sonst haengt man bei einem hartnaeckigen Wort fest und uebt nichts
/// sonst. Bei nur einer Karte gilt die Regel nicht — sonst bliebe der Stapel
/// stehen.
SprachKarte? naechsteKarte({
  required List<SprachKarte> karten,
  required Map<String, Kartenbilanz> bilanz,
  String? zuletzt,
}) {
  if (karten.isEmpty) return null;

  var auswahl = karten.where((k) => k.sollText != zuletzt).toList();
  if (auswahl.isEmpty) auswahl = karten;

  auswahl.sort((a, b) {
    final ba = bilanz[a.sollText];
    final bb = bilanz[b.sollText];
    final aNeu = ba == null || ba.versuche == 0;
    final bNeu = bb == null || bb.versuche == 0;
    if (aNeu != bNeu) return aNeu ? -1 : 1;
    if (aNeu && bNeu) return 0;
    final quote = ba!.quote.compareTo(bb!.quote);
    if (quote != 0) return quote;
    return ba.versuche.compareTo(bb.versuche);
  });
  return auswahl.first;
}
