class VermehrungsEreignis {
  final String id;
  final String methode;
  final DateTime erstelltAm;
  final String? stammvolkId;
  final String? jungvolkId;
  final bool osBeiErstellung;
  final String? notiz;
  const VermehrungsEreignis({
    required this.id, required this.methode, required this.erstelltAm,
    this.stammvolkId, this.jungvolkId, this.osBeiErstellung = false, this.notiz,
  });

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory VermehrungsEreignis.fromJson(Map<String, dynamic> j) => VermehrungsEreignis(
        id: j['id'] as String,
        methode: j['methode'] as String,
        erstelltAm: DateTime.parse(j['erstellt_am'] as String),
        stammvolkId: j['stammvolk_id'] as String?,
        jungvolkId: j['jungvolk_id'] as String?,
        osBeiErstellung: (j['os_bei_erstellung'] as bool?) ?? false,
        notiz: j['notiz'] as String?,
      );

  /// Ohne betrieb_id/id — DB-Default/gen_random_uuid.
  Map<String, dynamic> toInsertJson() => {
        'methode': methode,
        'erstellt_am': _iso(erstelltAm),
        'stammvolk_id': stammvolkId,
        'jungvolk_id': jungvolkId,
        'os_bei_erstellung': osBeiErstellung,
        'notiz': notiz,
      };
}
