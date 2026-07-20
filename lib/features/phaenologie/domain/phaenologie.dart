/// Phänologie-Fachkonstante (Muster krankheit.dart, pure, KEIN DB-Seed).
/// Importiert bewusst NICHT aufgaben/domain — die Abhängigkeit ist strikt einseitig
/// (saison_regeln.dart -> phaenologie.dart).
library;

enum PhaenoAnker { fruehjahr, tracht }

class Indikatorpflanze {
  final String key;
  final String name;
  final PhaenoAnker anker;
  /// Kalibrier-DOY am Referenzstandort (Mittelland-nah), bei dem Offset 0 die Basis-Regelfenster
  /// trifft. Als NICHT-SCHALTJAHR-DOY definiert (in Schaltjahren driftet der Offset für Anker nach
  /// dem 29.2. um max. 1 Tag — operativ vernachlässigbar). Richtwerte → Fachstellen-Check.
  final int referenzDoy;
  const Indikatorpflanze({required this.key, required this.name, required this.anker, required this.referenzDoy});
}

const kIndikatorpflanzen = <Indikatorpflanze>[
  // Frühjahr — treibt die Frühjahrs-/Aufbauregeln (Offset). Alle bis in Hochlagen beobachtbar.
  Indikatorpflanze(key: 'salweide',      name: 'Sal-Weide',            anker: PhaenoAnker.fruehjahr, referenzDoy: 74),  // ~15.3.
  Indikatorpflanze(key: 'kirschbluete',  name: 'Kirschblüte',          anker: PhaenoAnker.fruehjahr, referenzDoy: 110), // ~20.4.
  Indikatorpflanze(key: 'loewenzahn',    name: 'Löwenzahn',            anker: PhaenoAnker.fruehjahr, referenzDoy: 115), // ~25.4. (Default)
  // Tracht — treibt Honigernte + (per Kette) Varroa-Sommerbehandlung. Hochlagen-Zeiger zuerst.
  // Hochlagen-Zeiger (Alpenrose/Bergwiesen/Weidenröschen) blühen nicht im Mittelland → referenzDoy
  // ist ein KALIBRIER-Wert: normale Arosa-Blüte minus Ziel-Offset (~+42) ⇒ Ernte Mitte/Ende Juli,
  // Behandlung (per Kette) Ende Juli. Tal-Zeiger (Linde/Edelkastanie) tragen ihren echten
  // Mittelland-Blüh-DOY ⇒ Offset ~0 für Tallagen-Mandanten. Alle Werte: Fachstellen-Check (Spec §10).
  Indikatorpflanze(key: 'alpenrose',     name: 'Alpenrose',            anker: PhaenoAnker.tracht,    referenzDoy: 125), // Blüte Arosa ~Mitte Juni → +42 (Default)
  Indikatorpflanze(key: 'bergwiesen',    name: 'Bergwiesen-Vollblüte', anker: PhaenoAnker.tracht,    referenzDoy: 125),
  Indikatorpflanze(key: 'weidenroeschen',name: 'Weidenröschen',        anker: PhaenoAnker.tracht,    referenzDoy: 148), // blüht später (~Anf. Juli)
  Indikatorpflanze(key: 'linde',         name: 'Linde',                anker: PhaenoAnker.tracht,    referenzDoy: 176), // Tal (~25.6.)
  Indikatorpflanze(key: 'edelkastanie',  name: 'Edelkastanie',         anker: PhaenoAnker.tracht,    referenzDoy: 182), // Tal (~1.7.)
];

const kDefaultIndikatorFruehjahr = 'loewenzahn';
const kDefaultIndikatorTracht = 'alpenrose';

/// Max. Betrag des phänologischen Offsets (Defense-in-Depth gegen Fehleingaben).
const kMaxOffsetTage = 60;

/// Katalog-Lookup (null bei unbekanntem/fehlendem Key — Drift-tolerant).
Indikatorpflanze? indikatorVon(String? key) {
  if (key == null) return null;
  for (final i in kIndikatorpflanzen) {
    if (i.key == key) return i;
  }
  return null;
}

/// Zeiger eines Ankers (für das gefilterte Dropdown).
List<Indikatorpflanze> indikatorenFuer(PhaenoAnker anker) =>
    kIndikatorpflanzen.where((i) => i.anker == anker).toList();

/// Tag im Jahr (1..366). Rein integer → DST-immun (keine Duration über Zeitumstellung).
int doyVon(DateTime d) {
  const kum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final istSchalt = (d.year % 4 == 0 && (d.year % 100 != 0 || d.year % 400 == 0));
  final schalt = (istSchalt && d.month > 2) ? 1 : 0;
  return kum[d.month - 1] + d.day + schalt;
}

/// Ergebnis der Honigreinheit-Prüfung (weicher Inline-Hinweis im Fütterungs-Formular).
enum HonigreinheitHinweis { keiner, verfaelschung, notfuetterung }

// zuckerwasser_1_1 (Jungvolk-Anfüttern, i. d. R. kein Honigraum) bewusst NICHT gewarnt → kein Fehlalarm.
const _kGewarnteFutterarten = {'zuckerwasser_3_2', 'invertsirup', 'futterteig'};

/// Zuckerfütterung während der (beobachteten) Tracht kann den erntbaren Honig verfälschen (BGD 4.2).
/// Feuert NUR, wenn eine Tracht-Beobachtung existiert ([trachtFenster] != null).
HonigreinheitHinweis honigreinheitHinweis({
  required String futterart,
  required String zweck,
  required DateTime datum,
  required (DateTime, DateTime)? trachtFenster,
}) {
  if (trachtFenster == null) return HonigreinheitHinweis.keiner;
  if (!_kGewarnteFutterarten.contains(futterart)) return HonigreinheitHinweis.keiner;
  final t = DateTime(datum.year, datum.month, datum.day);
  if (t.isBefore(trachtFenster.$1) || t.isAfter(trachtFenster.$2)) return HonigreinheitHinweis.keiner;
  return zweck == 'notfuetterung' ? HonigreinheitHinweis.notfuetterung : HonigreinheitHinweis.verfaelschung;
}
