/// Eine gelernte Lautvariante: „so klingt es bei mir" → „so heisst es richtig".
class Korrekturregel {
  final String falsch;
  final String richtig;
  const Korrekturregel({required this.falsch, required this.richtig});
}

/// Eine vorgenommene Ersetzung, bezogen auf den ERGEBNISTEXT.
/// `start` und `laenge` zeigen auf die eingesetzte Fassung, damit die Anzeige
/// die Stelle ohne Nachrechnen einfaerben kann.
class Ersetzung {
  final int start;
  final int laenge;
  final String vorher;
  final String nachher;
  const Ersetzung({
    required this.start,
    required this.laenge,
    required this.vorher,
    required this.nachher,
  });
}

class Korrigiert {
  final String text;
  final List<Ersetzung> ersetzungen;
  const Korrigiert({required this.text, required this.ersetzungen});
}

/// Wendet gelernte Regeln auf ein Transkript an.
///
/// **Ganze Woerter, kein Teilstring.** Beim ZAEHLEN ist ein Teiltreffer
/// erwuenscht („Varroamilben" enthaelt „Varroa"); beim ERSETZEN waere er
/// zerstoererisch — aus „Minutenzeiger" wuerde „Milbenzeiger".
///
/// Regeln greifen nur einmal: Durchlaufen wird der EINGABETEXT, nie das
/// Ergebnis. Sonst koennte eine Regelkette (a→b, b→c) ein Wort weiterreichen,
/// bis niemand mehr nachvollzieht, woher es kam.
///
/// v1 kennt nur Ein-Wort-Regeln. Alle Verhoerer des Feldtests sind
/// Ein-Wort-Faelle (weissenzellen, Minuten, schwadentrieb); mehrteilige Regeln
/// kaemen erst mit Belegen dafuer, dass es sie braucht.
Korrigiert korrekturenAnwenden({required String transkript, required List<Korrekturregel> regeln}) {
  if (regeln.isEmpty || transkript.isEmpty) {
    return Korrigiert(text: transkript, ersetzungen: const []);
  }
  final nachSchluessel = <String, String>{
    for (final r in regeln)
      if (r.falsch.trim().isNotEmpty) r.falsch.toLowerCase(): r.richtig,
  };

  final aus = StringBuffer();
  final ersetzungen = <Ersetzung>[];
  var gelesen = 0;

  for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(transkript)) {
    aus.write(transkript.substring(gelesen, m.start));
    final original = m[0]!;
    final ersatz = nachSchluessel[original.toLowerCase()];
    if (ersatz == null) {
      aus.write(original);
    } else {
      ersetzungen.add(
        Ersetzung(start: aus.length, laenge: ersatz.length, vorher: original, nachher: ersatz),
      );
      aus.write(ersatz);
    }
    gelesen = m.end;
  }
  aus.write(transkript.substring(gelesen));

  return Korrigiert(text: aus.toString(), ersetzungen: ersetzungen);
}
