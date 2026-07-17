class Koenigin {
  final String id;
  final String? kennung;
  final int? schlupfjahr;
  final String? rasse;
  final String? linie;
  final String? herkunft;
  final String begattungsart; // standbegattung|belegstelle|instrumentell|unbekannt
  final String status; // aktiv|ersetzt|tot|verschollen
  final String? volkId;
  final DateTime? zugeordnetAm;
  final DateTime? ersetztAm;
  final String? mutterKoeniginId;
  final String? notes;

  const Koenigin({
    required this.id,
    this.kennung,
    this.schlupfjahr,
    this.rasse,
    this.linie,
    this.herkunft,
    this.begattungsart = 'unbekannt',
    this.status = 'aktiv',
    this.volkId,
    this.zugeordnetAm,
    this.ersetztAm,
    this.mutterKoeniginId,
    this.notes,
  });

  factory Koenigin.fromJson(Map<String, dynamic> j) => Koenigin(
        id: j['id'] as String,
        kennung: j['kennung'] as String?,
        schlupfjahr: j['schlupfjahr'] as int?,
        rasse: j['rasse'] as String?,
        linie: j['linie'] as String?,
        herkunft: j['herkunft'] as String?,
        begattungsart: (j['begattungsart'] as String?) ?? 'unbekannt',
        status: (j['status'] as String?) ?? 'aktiv',
        volkId: j['volk_id'] as String?,
        zugeordnetAm: j['zugeordnet_am'] != null ? DateTime.parse(j['zugeordnet_am'] as String) : null,
        ersetztAm: j['ersetzt_am'] != null ? DateTime.parse(j['ersetzt_am'] as String) : null,
        mutterKoeniginId: j['mutter_koenigin_id'] as String?,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'kennung': kennung,
        'schlupfjahr': schlupfjahr,
        'rasse': rasse,
        'linie': linie,
        'herkunft': herkunft,
        'begattungsart': begattungsart,
        'status': status,
        'notes': notes,
      };
}
