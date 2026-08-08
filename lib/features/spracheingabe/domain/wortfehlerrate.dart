/// Zerlegt einen Text in vergleichbare Woerter.
///
/// Bewusst grosszuegig normalisiert: Gross-/Kleinschreibung und Satzzeichen
/// sind fuer die Frage „hat der Erkenner es verstanden" belanglos, und die
/// Anbieter setzen beides unterschiedlich. Wer hier streng vergliche, wuerde
/// vor allem Formatierungsunterschiede messen.
List<String> woerterVon(String text) => RegExp(
  r'[\p{L}\p{N}]+',
  unicode: true,
).allMatches(text.toLowerCase()).map((m) => m[0]!).toList();

/// Wortfehlerrate zwischen Soll- und Ist-Text.
///
/// Das klassische Mass der Spracherkennung: (Ersetzungen + Einfuegungen +
/// Loeschungen) geteilt durch die Anzahl Soll-Woerter. 0.0 ist fehlerfrei.
///
/// **Werte ueber 1.0 sind moeglich und werden absichtlich NICHT gekappt.**
/// Sie entstehen, wenn der Erkenner mehr erfindet, als dastand — genau das
/// Verhalten, das Whisper bei Stille zeigt. Eine auf 1.0 gedeckelte Zahl
/// wuerde diesen Fall wie einen gewoehnlichen Fehlschlag aussehen lassen.
double wortfehlerrate({required String soll, required String ist}) {
  final s = woerterVon(soll);
  final i = woerterVon(ist);
  if (s.isEmpty) return 0.0; // nichts zu treffen — keine Division durch null
  return _abstand(s, i) / s.length;
}

/// Levenshtein-Abstand auf Wortebene, zeilenweise gerechnet.
int _abstand(List<String> a, List<String> b) {
  var vorige = List<int>.generate(b.length + 1, (j) => j);
  for (var x = 1; x <= a.length; x++) {
    final aktuelle = List<int>.filled(b.length + 1, 0);
    aktuelle[0] = x;
    for (var y = 1; y <= b.length; y++) {
      final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
      final ersetzen = vorige[y - 1] + kosten;
      final loeschen = vorige[y] + 1;
      final einfuegen = aktuelle[y - 1] + 1;
      aktuelle[y] = ersetzen < loeschen
          ? (ersetzen < einfuegen ? ersetzen : einfuegen)
          : (loeschen < einfuegen ? loeschen : einfuegen);
    }
    vorige = aktuelle;
  }
  return vorige[b.length];
}
