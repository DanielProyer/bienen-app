/// Volk-Bewertung (Baustein D2a). 6 BGD-Achsen, Skala 1-4, alle 'höher = besser'. Pure.
class BewertungsAchse {
  final String key;          // = DB-Spaltenname
  final String label;
  final List<String> anker;  // 4 Verhaltensanker, Index 0 = Note 1 … Index 3 = Note 4
  const BewertungsAchse({required this.key, required this.label, required this.anker});
}

const kBewertungsAchsen = <BewertungsAchse>[
  BewertungsAchse(key: 'sanftmut', label: 'Sanftmut',
      anker: ['stechlustig', 'nervös', 'sanft', 'sehr sanft']),
  BewertungsAchse(key: 'wabensitz', label: 'Wabensitz',
      anker: ['flüchtig/abtropfend', 'laufend', 'ruhig', 'fest sitzend']),
  BewertungsAchse(key: 'schwarmtraegheit', label: 'Schwarmträgheit',
      anker: ['geschwärmt/starker Trieb', 'deutlicher Trieb', 'geringer Trieb', 'kein Schwarmtrieb']),
  BewertungsAchse(key: 'brutbild', label: 'Brutbild',
      anker: ['stark löchrig/Buckelbrut', 'lückig', 'gut, wenige Lücken', 'geschlossen/lückenlos']),
  BewertungsAchse(key: 'volksstaerke', label: 'Volksstärke',
      anker: ['sehr schwach/Serbel', 'schwach', 'durchschnittlich', 'stark (jahreszeit-entsprechend)']),
  BewertungsAchse(key: 'gesundheit', label: 'Gesundheit',
      anker: ['stark belastet/Symptome', 'Varroa-/Krankheitszeichen', 'leichte Auffälligkeit', 'keine Auffälligkeiten']),
];

class VolkBewertung {
  final String id;
  final String volkId;
  final String? koeniginId;
  final DateTime bewertetAm;
  final int sanftmut, wabensitz, schwarmtraegheit, brutbild, volksstaerke, gesundheit;
  final String? notiz;
  const VolkBewertung({
    required this.id, required this.volkId, this.koeniginId, required this.bewertetAm,
    required this.sanftmut, required this.wabensitz, required this.schwarmtraegheit,
    required this.brutbild, required this.volksstaerke, required this.gesundheit, this.notiz,
  });

  int wertFuer(String key) => switch (key) {
        'sanftmut' => sanftmut,
        'wabensitz' => wabensitz,
        'schwarmtraegheit' => schwarmtraegheit,
        'brutbild' => brutbild,
        'volksstaerke' => volksstaerke,
        'gesundheit' => gesundheit,
        _ => throw ArgumentError('unbekannte Achse $key'),
      };

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory VolkBewertung.fromJson(Map<String, dynamic> j) => VolkBewertung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        koeniginId: j['koenigin_id'] as String?,
        bewertetAm: DateTime.parse(j['bewertet_am'] as String),
        sanftmut: j['sanftmut'] as int,
        wabensitz: j['wabensitz'] as int,
        schwarmtraegheit: j['schwarmtraegheit'] as int,
        brutbild: j['brutbild'] as int,
        volksstaerke: j['volksstaerke'] as int,
        gesundheit: j['gesundheit'] as int,
        notiz: j['notiz'] as String?,
      );

  /// Ohne betrieb_id/id (DB-Default). koenigin_id = Referenz.
  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'koenigin_id': koeniginId,
        'bewertet_am': _iso(bewertetAm),
        'sanftmut': sanftmut,
        'wabensitz': wabensitz,
        'schwarmtraegheit': schwarmtraegheit,
        'brutbild': brutbild,
        'volksstaerke': volksstaerke,
        'gesundheit': gesundheit,
        'notiz': notiz,
      };
}

class SaisonAggregat {
  final Map<String, double> achsen; // key → aggregierter Wert
  final double gesamtnote;          // Ø der 6 rohen Achsenwerte (vollpräzise; Rundung nur Anzeige)
  final int anzahl;
  const SaisonAggregat({required this.achsen, required this.gesamtnote, required this.anzahl});
}

/// Saison-Aggregat aus den (1..n) Bewertungen EINES Volks EINER Saison. null wenn leer.
/// Je Achse Mittelwert; schwarmtraegheit = Minimum (BGD: ein Schwarm zählt).
SaisonAggregat? aggregiereSaison(List<VolkBewertung> bewertungen) {
  if (bewertungen.isEmpty) return null;
  final achsen = <String, double>{};
  for (final a in kBewertungsAchsen) {
    final werte = bewertungen.map((b) => b.wertFuer(a.key)).toList();
    achsen[a.key] = a.key == 'schwarmtraegheit'
        ? werte.reduce((x, y) => x < y ? x : y).toDouble()      // Minimum
        : werte.reduce((x, y) => x + y) / werte.length;         // Mittelwert
  }
  final gesamt = achsen.values.reduce((x, y) => x + y) / achsen.length;
  return SaisonAggregat(achsen: achsen, gesamtnote: gesamt, anzahl: bewertungen.length);
}
