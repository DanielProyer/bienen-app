class Standort {
  final String id;
  final String name;
  final String? adresse;
  final String? parzelle;
  final double? gpsLat;
  final double? gpsLng;
  final int? hoeheM;
  final String? kanton;
  final String? amtlicheStandnummer;
  final String? inspektionskreis;
  final String status; // besetzt|unbesetzt|aufgeloest
  final DateTime? aufgeloestAm;
  final String? trachtnotiz;
  final bool sperrbezirk;
  final String? notes;
  final int sortOrder;

  const Standort({
    required this.id,
    required this.name,
    this.adresse,
    this.parzelle,
    this.gpsLat,
    this.gpsLng,
    this.hoeheM,
    this.kanton,
    this.amtlicheStandnummer,
    this.inspektionskreis,
    this.status = 'besetzt',
    this.aufgeloestAm,
    this.trachtnotiz,
    this.sperrbezirk = false,
    this.notes,
    this.sortOrder = 0,
  });

  factory Standort.fromJson(Map<String, dynamic> j) => Standort(
        id: j['id'] as String,
        name: j['name'] as String,
        adresse: j['adresse'] as String?,
        parzelle: j['parzelle'] as String?,
        gpsLat: (j['gps_lat'] as num?)?.toDouble(),
        gpsLng: (j['gps_lng'] as num?)?.toDouble(),
        hoeheM: j['hoehe_m'] as int?,
        kanton: j['kanton'] as String?,
        amtlicheStandnummer: j['amtliche_standnummer'] as String?,
        inspektionskreis: j['inspektionskreis'] as String?,
        status: (j['status'] as String?) ?? 'besetzt',
        aufgeloestAm: j['aufgeloest_am'] != null ? DateTime.parse(j['aufgeloest_am'] as String) : null,
        trachtnotiz: j['trachtnotiz'] as String?,
        sperrbezirk: (j['sperrbezirk'] as bool?) ?? false,
        notes: j['notes'] as String?,
        sortOrder: (j['sort_order'] as int?) ?? 0,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'adresse': adresse,
        'parzelle': parzelle,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'hoehe_m': hoeheM,
        'kanton': kanton,
        'amtliche_standnummer': amtlicheStandnummer,
        'inspektionskreis': inspektionskreis,
        'status': status,
        'aufgeloest_am': aufgeloestAm?.toIso8601String(),
        'trachtnotiz': trachtnotiz,
        'sperrbezirk': sperrbezirk,
        'notes': notes,
        'sort_order': sortOrder,
      };
}
