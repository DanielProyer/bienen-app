import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Was ein Anbieter über alle Messungen hinweg geleistet hat.
class Anbieterbilanz {
  final String anbieter;

  /// Zahl der VERWERTBAREN Messungen (ohne Fehlschläge).
  final int messungen;

  /// Zahl der Ausfälle. Bewusst getrennt gezählt: Ein Dienst, der nicht
  /// antwortet, ist etwas anderes als einer, der schlecht erkennt — und für
  /// die Anbieterwahl zählt beides, aber unterschiedlich.
  final int fehlschlaege;

  /// `null`, wenn nichts Verwertbares vorliegt — **nicht** 0.0. Eine Null
  /// hiesse „gemessen und ganz schlecht"; nichts gemessen ist etwas anderes,
  /// und die Anzeige muss das unterscheiden können.
  final double? trefferQuoteMittel;

  /// Mittel nur über Messungen, die überhaupt eine Wortfehlerrate haben.
  /// Wortkarten haben keine (siehe `SprachKarte.zuZaehlen`) und dürfen den
  /// Satz-Mittelwert nicht verwässern.
  final double? wortfehlerMittel;

  /// Womit tatsächlich gemessen wurde. Der Rückfallweg der Edge Function
  /// hängt „(ohne Wortliste)" an den Namen — ohne diese Liste vergliche man
  /// später Zahlen, die nicht vergleichbar sind (D-103e).
  final List<String> modelle;

  const Anbieterbilanz({
    required this.anbieter,
    required this.messungen,
    required this.fehlschlaege,
    required this.trefferQuoteMittel,
    required this.wortfehlerMittel,
    required this.modelle,
  });
}

/// Fasst Messungen je Anbieter zusammen.
///
/// Sortiert nach Trefferquote, das Beste zuerst; Anbieter ohne verwertbare
/// Messung stehen am Ende — sie sind keine Sieger, aber auch keine Verlierer.
List<Anbieterbilanz> anbieterBilanzieren(List<SprachErgebnis> ergebnisse) {
  final nachAnbieter = <String, List<SprachErgebnis>>{};
  for (final e in ergebnisse) {
    nachAnbieter.putIfAbsent(e.anbieter, () => []).add(e);
  }

  double? mittel(Iterable<double?> werte) {
    final da = werte.whereType<double>().toList();
    if (da.isEmpty) return null;
    return da.reduce((a, b) => a + b) / da.length;
  }

  final bilanzen = nachAnbieter.entries.map((eintrag) {
    final gut = eintrag.value.where((e) => e.fehler == null).toList();
    return Anbieterbilanz(
      anbieter: eintrag.key,
      messungen: gut.length,
      fehlschlaege: eintrag.value.length - gut.length,
      trefferQuoteMittel: mittel(gut.map((e) => e.trefferQuote)),
      wortfehlerMittel: mittel(gut.map((e) => e.wortfehlerrate)),
      modelle: {
        for (final e in gut)
          if (e.modell.trim().isNotEmpty) e.modell.trim(),
      }.toList(),
    );
  }).toList();

  bilanzen.sort((a, b) {
    final qa = a.trefferQuoteMittel;
    final qb = b.trefferQuoteMittel;
    if (qa == null && qb == null) return a.anbieter.compareTo(b.anbieter);
    if (qa == null) return 1;
    if (qb == null) return -1;
    return qb.compareTo(qa);
  });
  return bilanzen;
}
