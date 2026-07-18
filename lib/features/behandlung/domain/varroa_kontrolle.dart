class VarroaKontrolle {
  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String methode; // gemuell | puderzucker | auswaschung
  final int? messdauerTage;
  final int milbenGesamt;
  final int? bienenProbe;
  final String? notiz;

  const VarroaKontrolle({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    required this.methode,
    this.messdauerTage,
    required this.milbenGesamt,
    this.bienenProbe,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory VarroaKontrolle.fromJson(Map<String, dynamic> j) => VarroaKontrolle(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        methode: j['methode'] as String,
        messdauerTage: j['messdauer_tage'] as int?,
        milbenGesamt: j['milben_gesamt'] as int,
        bienenProbe: j['bienen_probe'] as int?,
        notiz: j['notiz'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'durchgefuehrt_am': _iso(durchgefuehrtAm),
        'methode': methode,
        'messdauer_tage': messdauerTage,
        'milben_gesamt': milbenGesamt,
        'bienen_probe': bienenProbe,
        'notiz': notiz,
      };
}
