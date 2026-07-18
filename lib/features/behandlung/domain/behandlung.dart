class Behandlung {
  final String id;
  final String volkId;
  final DateTime datumBeginn;
  final DateTime? datumEnde;
  final String? praeparat;
  final String wirkstoff;
  final num? mengeProVolk;
  final String? einheit;
  final String? konzentration;
  final String anwendungsart;
  final String? indikation;
  final num? aussentemperaturC;
  final int? wartefristTage;
  final String? charge;
  final String verantwortlichePerson;
  final String? materialId;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;
  final String? notiz;

  const Behandlung({
    required this.id,
    required this.volkId,
    required this.datumBeginn,
    this.datumEnde,
    this.praeparat,
    required this.wirkstoff,
    this.mengeProVolk,
    this.einheit,
    this.konzentration,
    required this.anwendungsart,
    this.indikation,
    this.aussentemperaturC,
    this.wartefristTage,
    this.charge,
    required this.verantwortlichePerson,
    this.materialId,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Behandlung.fromJson(Map<String, dynamic> j) => Behandlung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        datumBeginn: _d(j['datum_beginn']),
        datumEnde: j['datum_ende'] != null ? _d(j['datum_ende']) : null,
        praeparat: j['praeparat'] as String?,
        wirkstoff: j['wirkstoff'] as String,
        mengeProVolk: j['menge_pro_volk'] as num?,
        einheit: j['einheit'] as String?,
        konzentration: j['konzentration'] as String?,
        anwendungsart: j['anwendungsart'] as String,
        indikation: j['indikation'] as String?,
        aussentemperaturC: j['aussentemperatur_c'] as num?,
        wartefristTage: j['wartefrist_tage'] as int?,
        charge: j['charge'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String,
        materialId: j['material_id'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
        notiz: j['notiz'] as String?,
      );
}
