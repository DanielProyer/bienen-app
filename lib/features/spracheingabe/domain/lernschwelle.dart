/// Wie oft derselbe Verhoerer auftreten muss, bevor er zur Regel wird.
///
/// Raeuspern, ein Windstoss oder ein verschlucktes Wort erzeugen einmalige
/// Abweichungen. Wuerde daraus sofort eine Regel, lernte die App Zufall — und
/// wendete ihn danach auf jedes Transkript an. Zwei ist der billigste
/// verfuegbare Schutz dagegen.
const int lernschwelle = 2;

/// Begriffe, die NIE geboostet oder ersetzt werden (Entscheid D-99d).
///
/// Seuchen: Wortlisten koennen Begriffe EINFUEGEN, die nie gesagt wurden. Ein
/// halluzinierter Faulbrut-Befund im vorbefuellten Formular waere gravierender
/// als ein fehlender — diese Begriffe loest die Sprachmodell-Stufe aus dem
/// Kontext auf.
///
/// Alltagswoerter mit imkerlicher Sonderbedeutung: regulaere deutsche Woerter.
/// Sie zu ersetzen erzeugt Uebererkennung im uebrigen Text.
const Set<String> gesperrteBegriffe = {
  'faulbrut',
  'sauerbrut',
  'amerikanische faulbrut',
  'europäische faulbrut',
  'nosema',
  'beute',
  'windel',
  'stifte',
  'schied',
  'rahmen',
};

/// Entscheidet, ob aus einem beobachteten Verhoerer eine Korrekturregel werden
/// darf.
///
/// **Beide Seiten werden gegen die Sperrliste geprueft, nicht nur das Ziel.**
/// Eine Regel `faulbrut → irgendetwas` wuerde sonst jeden echt gesagten
/// Seuchenbegriff still aus dem Transkript schreiben — die Umkehrung genau der
/// Gefahr, wegen der die Liste ueberhaupt existiert. Dasselbe gilt fuer
/// Alltagswoerter: `beute → baute` machte aus jeder Beute eine Baute.
bool darfRegelWerden({
  required int treffer,
  required String falsch,
  required String richtig,
}) {
  final quelle = falsch.trim().toLowerCase();
  final ziel = richtig.trim().toLowerCase();
  if (quelle.isEmpty || ziel.isEmpty) return false;
  if (gesperrteBegriffe.contains(quelle) || gesperrteBegriffe.contains(ziel)) {
    return false;
  }
  return treffer >= lernschwelle;
}
