// Fachvokabular der Imkerei, das Standardmodelle verhoeren.
//
// Zwei Begriffsgruppen fehlen hier BEWUSST (Entscheid D-99d):
//
//  * Seuchen (Faulbrut, Sauerbrut, Amerikanische Faulbrut, Nosema): Wortlisten
//    koennen Begriffe EINFUEGEN, die nie gesagt wurden — die Anbieter warnen
//    selbst davor. Ein halluzinierter Seuchenbefund im vorbefuellten Formular
//    waere gravierender als ein fehlender. Diese Begriffe loest die
//    Sprachmodell-Stufe aus dem Kontext auf.
//
//  * Alltagswoerter mit imkerlicher Sonderbedeutung (Beute, Windel, Stifte,
//    Schied, Rahmen): regulaere deutsche Woerter. Sie zu boosten erzeugt
//    Uebererkennung im uebrigen Text.
//
// Die Liste ist bewusst kurz. Die Anbieter empfehlen 20-50 Begriffe; mehr
// verschlechtert laut Google die Erkennung der NICHT geboosteten Woerter.
export const FACHWOERTER: string[] = [
  'Varroa',
  'Varroamilbe',
  'Milben',
  'Weiselzellen',
  'Weiselrichtigkeit',
  'weiselrichtig',
  'weisellos',
  'Drohnenbrut',
  'Drohnenrahmen',
  'Schwarmtrieb',
  'Schwarmzellen',
  'Ableger',
  'Kunstschwarm',
  'Dadant',
  'Zander',
  'Mittelwand',
  'Absperrgitter',
  'Honigraum',
  'Brutraum',
  'Wabengasse',
  'Gemüll',
  'Ameisensäure',
  'Oxalsäure',
  'Sublimation',
  'Trachtende',
  'Räuberei',
  'Kalkbrut',
  'Buckfast',
  'Bienenflucht',
  'Futterteig',
];

/// Die Begriffe, an denen der Feldtest gescheitert ist. Sie werden in der
/// Auswertung eigens ausgewiesen, weil an ihnen der Nutzen des Verfahrens
/// haengt — nicht an der Gesamtfehlerrate.
export const PRUEFBEGRIFFE: string[] = [
  'Weiselzellen',
  'Milben',
  'Schwarmtrieb',
  'Drohnenbrut',
  'Varroa',
  'Ableger',
];
