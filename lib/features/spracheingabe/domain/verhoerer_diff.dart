import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart' show woerterVon;

/// Ein Kandidatenpaar. `falsch` steht normalisiert (klein), weil danach
/// gesucht wird; `richtig` behaelt die Schreibweise des Nutzers, weil sie im
/// Text erscheint.
class Verhoererpaar {
  final String falsch;
  final String richtig;
  const Verhoererpaar({required this.falsch, required this.richtig});

  @override
  bool operator ==(Object other) =>
      other is Verhoererpaar && other.falsch == falsch && other.richtig == richtig;

  @override
  int get hashCode => Object.hash(falsch, richtig);
}

/// Zieht Verhoererpaare aus dem Unterschied zwischen Erkanntem und der vom
/// Nutzer korrigierten Fassung.
///
/// **Nur 1:1-Ersetzungen werden Paare.** Ein eingefuegtes Wort ist eine
/// Ergaenzung, ein geloeschtes eine Streichung — beides sagt nichts darueber
/// aus, wie ein Wort bei diesem Sprecher klingt. Sie als Paare zu fuehren
/// wuerde die Regeltabelle mit Rauschen fuellen.
List<Verhoererpaar> verhoererAus({required String erkannt, required String korrigiert}) {
  final a = woerterVon(erkannt);
  // Die Roh-Woerter der korrigierten Fassung, um die Schreibweise zu behalten.
  final bRoh = RegExp(
    r'[\p{L}\p{N}]+',
    unicode: true,
  ).allMatches(korrigiert).map((m) => m[0]!).toList();
  final b = bRoh.map((w) => w.toLowerCase()).toList();
  if (a.isEmpty || b.isEmpty) return const [];

  // Levenshtein-Matrix, danach rueckwaerts durch die Entscheidungen laufen.
  final d = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var x = 0; x <= a.length; x++) {
    d[x][0] = x;
  }
  for (var y = 0; y <= b.length; y++) {
    d[0][y] = y;
  }
  for (var x = 1; x <= a.length; x++) {
    for (var y = 1; y <= b.length; y++) {
      final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
      final e = d[x - 1][y - 1] + kosten;
      final l = d[x - 1][y] + 1;
      final i = d[x][y - 1] + 1;
      d[x][y] = e < l ? (e < i ? e : i) : (l < i ? l : i);
    }
  }

  final paare = <Verhoererpaar>[];
  var x = a.length, y = b.length;
  while (x > 0 && y > 0) {
    final kosten = a[x - 1] == b[y - 1] ? 0 : 1;
    if (d[x][y] == d[x - 1][y - 1] + kosten) {
      if (kosten == 1) {
        paare.add(Verhoererpaar(falsch: a[x - 1], richtig: bRoh[y - 1]));
      }
      x--;
      y--;
    } else if (d[x][y] == d[x - 1][y] + 1) {
      x--; // Streichung
    } else {
      y--; // Ergaenzung
    }
  }
  return paare.reversed.toList();
}
