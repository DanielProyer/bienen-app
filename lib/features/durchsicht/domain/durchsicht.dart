import 'wabe.dart';

class Durchsicht {
  static const auffaelligkeitenWhitelist = <String>{
    'kalkbrut', 'sackbrut', 'faulbrut_verdacht', 'sauerbrut_verdacht',
    'ruhr', 'raeuberei', 'wachsmotte', 'varroa_sichtbar', 'kahlflug',
  };

  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String? wetter;
  final num? temperaturC;
  final int? dauerMin;
  final String? weiselzustand;
  final bool koeniginGesehen;
  final bool stifteGesehen;
  final String? weiselzellen;
  final int? weiselzellenAnzahl;
  final String? brutbild;
  final num? brutWaben;
  final num? staerkeWabengassen;
  final num? futterKg;
  final String? pollen;
  final String? platz;
  final int? sanftmut;
  final int? wabensitz;
  final List<String> auffaelligkeiten;
  final String? massnahmen;
  final DateTime? naechsteDurchsichtAm;
  final List<String> fotoUrls; // Storage-PFADE
  final String? notiz;
  final List<WabeBeobachtung> waben;

  const Durchsicht({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    this.wetter,
    this.temperaturC,
    this.dauerMin,
    this.weiselzustand,
    this.koeniginGesehen = false,
    this.stifteGesehen = false,
    this.weiselzellen,
    this.weiselzellenAnzahl,
    this.brutbild,
    this.brutWaben,
    this.staerkeWabengassen,
    this.futterKg,
    this.pollen,
    this.platz,
    this.sanftmut,
    this.wabensitz,
    this.auffaelligkeiten = const [],
    this.massnahmen,
    this.naechsteDurchsichtAm,
    this.fotoUrls = const [],
    this.notiz,
    this.waben = const [],
  });

  static List<String> gueltigeFlags(List<String> flags) =>
      flags.where(auffaelligkeitenWhitelist.contains).toList();

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Durchsicht.fromJson(Map<String, dynamic> j) => Durchsicht(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        wetter: j['wetter'] as String?,
        temperaturC: j['temperatur_c'] as num?,
        dauerMin: j['dauer_min'] as int?,
        weiselzustand: j['weiselzustand'] as String?,
        koeniginGesehen: (j['koenigin_gesehen'] as bool?) ?? false,
        stifteGesehen: (j['stifte_gesehen'] as bool?) ?? false,
        weiselzellen: j['weiselzellen'] as String?,
        weiselzellenAnzahl: j['weiselzellen_anzahl'] as int?,
        brutbild: j['brutbild'] as String?,
        brutWaben: j['brut_waben'] as num?,
        staerkeWabengassen: j['staerke_wabengassen'] as num?,
        futterKg: j['futter_kg'] as num?,
        pollen: j['pollen'] as String?,
        platz: j['platz'] as String?,
        sanftmut: j['sanftmut'] as int?,
        wabensitz: j['wabensitz'] as int?,
        auffaelligkeiten:
            ((j['auffaelligkeiten'] as List?)?.cast<String>() ?? const []),
        massnahmen: j['massnahmen'] as String?,
        naechsteDurchsichtAm: j['naechste_durchsicht_am'] != null
            ? _d(j['naechste_durchsicht_am'])
            : null,
        fotoUrls: ((j['foto_urls'] as List?)?.cast<String>() ?? const []),
        notiz: j['notiz'] as String?,
        waben: ((j['waben'] as List?)
                ?.map((e) => WabeBeobachtung.fromJson(e as Map<String, dynamic>))
                .toList()) ??
            const [],
      );

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'durchgefuehrt_am': _iso(durchgefuehrtAm),
        'wetter': wetter,
        'temperatur_c': temperaturC,
        'dauer_min': dauerMin,
        'weiselzustand': weiselzustand,
        'koenigin_gesehen': koeniginGesehen,
        'stifte_gesehen': stifteGesehen,
        'weiselzellen': weiselzellen,
        'weiselzellen_anzahl': weiselzellenAnzahl,
        'brutbild': brutbild,
        'brut_waben': brutWaben,
        'staerke_wabengassen': staerkeWabengassen,
        'futter_kg': futterKg,
        'pollen': pollen,
        'platz': platz,
        'sanftmut': sanftmut,
        'wabensitz': wabensitz,
        'auffaelligkeiten': gueltigeFlags(auffaelligkeiten),
        'massnahmen': massnahmen,
        'naechste_durchsicht_am':
            naechsteDurchsichtAm != null ? _iso(naechsteDurchsichtAm!) : null,
        'foto_urls': fotoUrls,
        'notiz': notiz,
        'waben': waben.isEmpty ? null : waben.map((w) => w.toJson()).toList(),
      };
}
