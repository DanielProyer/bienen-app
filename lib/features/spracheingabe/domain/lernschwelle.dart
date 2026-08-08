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
bool darfRegelWerden({required int treffer, required String richtig}) {
  final ziel = richtig.trim().toLowerCase();
  if (ziel.isEmpty) return false;
  if (gesperrteBegriffe.contains(ziel)) return false;
  return treffer >= lernschwelle;
}
