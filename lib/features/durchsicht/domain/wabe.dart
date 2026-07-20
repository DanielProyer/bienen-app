class WabeBeobachtung {
  final bool schied;
  final Set<String> inhalte;
  final bool koenigin;
  final bool weiselzelle;
  final bool stifte;
  const WabeBeobachtung({this.schied = false, this.inhalte = const {},
      this.koenigin = false, this.weiselzelle = false, this.stifte = false});

  static const kWabenInhalte = <String>{'brut', 'pollen', 'futter', 'honig', 'mittelwand', 'leer', 'baurahmen'};

  factory WabeBeobachtung.fromJson(Map<String, dynamic> j) {
    if ((j['schied'] as bool?) ?? false) return const WabeBeobachtung(schied: true);
    return WabeBeobachtung(
      inhalte: ((j['inhalte'] as List?)?.cast<String>().where(kWabenInhalte.contains).toSet()) ?? const {},
      koenigin: (j['koenigin'] as bool?) ?? false,
      weiselzelle: (j['weiselzelle'] as bool?) ?? false,
      stifte: (j['stifte'] as bool?) ?? false,
    );
  }
  Map<String, dynamic> toJson() => schied
      ? {'schied': true}
      : {
          if (inhalte.isNotEmpty) 'inhalte': inhalte.where(kWabenInhalte.contains).toList(),
          if (koenigin) 'koenigin': true,
          if (weiselzelle) 'weiselzelle': true,
          if (stifte) 'stifte': true,
        };
}

const kFutterKgProWabe = 2.0; // grober Richtwert (Füllgrad ignoriert) — nur Hinweis
bool _istWabe(WabeBeobachtung w) => !w.schied;

int brutWabenAus(List<WabeBeobachtung> ws) => ws.where((w) => _istWabe(w) && w.inhalte.contains('brut')).length;
bool koeniginAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.koenigin);
bool stifteAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.stifte);
num futterKgHinweisAus(List<WabeBeobachtung> ws) =>
    ws.where((w) => _istWabe(w) && (w.inhalte.contains('futter') || w.inhalte.contains('honig'))).length * kFutterKgProWabe;

/// Vorbefüllung der Kennzahlen aus den Waben — null wenn keine Waben (dann KEIN Overwrite).
class WabenVorbefuellung {
  final int brutWaben;
  final bool koeniginGesehen;
  final bool stifteGesehen;
  final num futterKgHinweis;
  const WabenVorbefuellung({required this.brutWaben, required this.koeniginGesehen,
      required this.stifteGesehen, required this.futterKgHinweis});
}
WabenVorbefuellung? vorbefuellungAus(List<WabeBeobachtung> ws) => ws.isEmpty
    ? null
    : WabenVorbefuellung(brutWaben: brutWabenAus(ws), koeniginGesehen: koeniginAus(ws),
        stifteGesehen: stifteAus(ws), futterKgHinweis: futterKgHinweisAus(ws));
