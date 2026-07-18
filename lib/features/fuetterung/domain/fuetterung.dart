class Fuetterung {
  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String zweck;
  final String futterart;
  final bool bioZertifiziert;
  final num mengeProVolkKg;
  final String? materialId;
  final String? verantwortlichePerson;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;
  final String? notiz;

  const Fuetterung({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    required this.zweck,
    required this.futterart,
    required this.bioZertifiziert,
    required this.mengeProVolkKg,
    this.materialId,
    this.verantwortlichePerson,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Fuetterung.fromJson(Map<String, dynamic> j) => Fuetterung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        zweck: j['zweck'] as String,
        futterart: j['futterart'] as String,
        bioZertifiziert: (j['bio_zertifiziert'] as bool?) ?? false,
        mengeProVolkKg: j['menge_pro_volk_kg'] as num,
        materialId: j['material_id'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
        notiz: j['notiz'] as String?,
      );
}
