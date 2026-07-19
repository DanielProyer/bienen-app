class Aufgabe {
  final String id;
  final String titel;
  final String? beschreibung;
  final String kategorie; // durchsicht|behandlung|fuetterung|schutz|werkstatt|verwaltung|sonstiges
  final DateTime faelligAm;
  final String prioritaet; // hoch|normal|niedrig
  final String status; // offen|erledigt|uebersprungen
  final DateTime? erledigtAm;
  final String? volkId;
  final String? standortId;
  final String quelle; // manuell|regel
  final String? regelKey;
  final int? saisonJahr;

  const Aufgabe({
    required this.id,
    required this.titel,
    this.beschreibung,
    required this.kategorie,
    required this.faelligAm,
    this.prioritaet = 'normal',
    this.status = 'offen',
    this.erledigtAm,
    this.volkId,
    this.standortId,
    this.quelle = 'manuell',
    this.regelKey,
    this.saisonJahr,
  });

  bool get istOffen => status == 'offen';

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory Aufgabe.fromJson(Map<String, dynamic> j) => Aufgabe(
        id: j['id'] as String,
        titel: j['titel'] as String,
        beschreibung: j['beschreibung'] as String?,
        kategorie: j['kategorie'] as String,
        faelligAm: _d(j['faellig_am']),
        prioritaet: (j['prioritaet'] as String?) ?? 'normal',
        status: (j['status'] as String?) ?? 'offen',
        erledigtAm: j['erledigt_am'] != null ? _d(j['erledigt_am']) : null,
        volkId: j['volk_id'] as String?,
        standortId: j['standort_id'] as String?,
        quelle: (j['quelle'] as String?) ?? 'manuell',
        regelKey: j['regel_key'] as String?,
        saisonJahr: j['saison_jahr'] as int?,
      );

  /// Ohne id/erledigt_am: id vergibt die DB, erledigt_am nur via setzeStatus.
  Map<String, dynamic> toInsertJson() => {
        'titel': titel,
        'beschreibung': beschreibung,
        'kategorie': kategorie,
        'faellig_am': _iso(faelligAm),
        'prioritaet': prioritaet,
        'status': status,
        'volk_id': volkId,
        'standort_id': standortId,
        'quelle': quelle,
        'regel_key': regelKey,
        'saison_jahr': saisonJahr,
      };
}
