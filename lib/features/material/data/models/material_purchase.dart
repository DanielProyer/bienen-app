class MaterialPurchase {
  final String id;
  final String materialId;
  final DateTime? gekauftAm;
  final double? menge;
  final double? stueckpreis;
  final double? gesamtpreis;
  final String? shop;
  final String? belegNr;
  final String? belegFoto;
  final String? notiz;
  final String? zahlungsart;

  const MaterialPurchase({
    required this.id,
    required this.materialId,
    this.gekauftAm,
    this.menge,
    this.stueckpreis,
    this.gesamtpreis,
    this.shop,
    this.belegNr,
    this.belegFoto,
    this.notiz,
    this.zahlungsart,
  });

  MaterialPurchase copyWith({
    String? id,
    String? materialId,
    DateTime? gekauftAm,
    double? menge,
    double? stueckpreis,
    double? gesamtpreis,
    String? shop,
    String? belegNr,
    String? belegFoto,
    String? notiz,
    String? zahlungsart,
  }) {
    return MaterialPurchase(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      gekauftAm: gekauftAm ?? this.gekauftAm,
      menge: menge ?? this.menge,
      stueckpreis: stueckpreis ?? this.stueckpreis,
      gesamtpreis: gesamtpreis ?? this.gesamtpreis,
      shop: shop ?? this.shop,
      belegNr: belegNr ?? this.belegNr,
      belegFoto: belegFoto ?? this.belegFoto,
      notiz: notiz ?? this.notiz,
      zahlungsart: zahlungsart ?? this.zahlungsart,
    );
  }

  factory MaterialPurchase.fromJson(Map<String, dynamic> json) {
    return MaterialPurchase(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      gekauftAm: json['gekauft_am'] != null
          ? DateTime.parse(json['gekauft_am'] as String)
          : null,
      menge: (json['menge'] as num?)?.toDouble(),
      stueckpreis: (json['stueckpreis'] as num?)?.toDouble(),
      gesamtpreis: (json['gesamtpreis'] as num?)?.toDouble(),
      shop: json['shop'] as String?,
      belegNr: json['beleg_nr'] as String?,
      belegFoto: json['beleg_foto'] as String?,
      notiz: json['notiz'] as String?,
      zahlungsart: json['zahlungsart'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_id': materialId,
      'gekauft_am': gekauftAm != null
          ? '${gekauftAm!.year.toString().padLeft(4, '0')}-'
              '${gekauftAm!.month.toString().padLeft(2, '0')}-'
              '${gekauftAm!.day.toString().padLeft(2, '0')}'
          : null,
      'menge': menge,
      'stueckpreis': stueckpreis,
      'gesamtpreis': gesamtpreis,
      'shop': shop,
      'beleg_nr': belegNr,
      'beleg_foto': belegFoto,
      'notiz': notiz,
      'zahlungsart': zahlungsart,
    };
  }
}
