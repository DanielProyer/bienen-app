class Gesundheitsereignis {
  final String id;
  final String volkId;
  final DateTime festgestelltAm;
  final String krankheit;
  final String? schweregrad;
  final String status;
  final DateTime? gemeldetAm;
  final bool laborEingesandt;
  final List<String> fotoUrls;
  final String? massnahme;
  final String? verantwortlichePerson;
  final String? notiz;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;

  const Gesundheitsereignis({
    required this.id,
    required this.volkId,
    required this.festgestelltAm,
    required this.krankheit,
    this.schweregrad,
    this.status = 'verdacht',
    this.gemeldetAm,
    this.laborEingesandt = false,
    this.fotoUrls = const [],
    this.massnahme,
    this.verantwortlichePerson,
    this.notiz,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
  });

  static const _abgeschlossen = {'saniert', 'ausgeheilt', 'erloschen'};
  bool get istAktiv => !isStorniert && !_abgeschlossen.contains(status);

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory Gesundheitsereignis.fromJson(Map<String, dynamic> j) => Gesundheitsereignis(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        festgestelltAm: _d(j['festgestellt_am']),
        krankheit: j['krankheit'] as String,
        schweregrad: j['schweregrad'] as String?,
        status: (j['status'] as String?) ?? 'verdacht',
        gemeldetAm: j['gemeldet_am'] != null ? _d(j['gemeldet_am']) : null,
        laborEingesandt: (j['labor_eingesandt'] as bool?) ?? false,
        fotoUrls: ((j['foto_urls'] as List?)?.cast<String>() ?? const []),
        massnahme: j['massnahme'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String?,
        notiz: j['notiz'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'festgestellt_am': _iso(festgestelltAm),
        'krankheit': krankheit,
        'schweregrad': schweregrad,
        'status': status,
        'gemeldet_am': gemeldetAm != null ? _iso(gemeldetAm!) : null,
        'labor_eingesandt': laborEingesandt,
        'foto_urls': fotoUrls,
        'massnahme': massnahme,
        'verantwortliche_person': verantwortlichePerson,
        'notiz': notiz,
      };
}
