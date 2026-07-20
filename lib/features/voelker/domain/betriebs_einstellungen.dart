class BetriebsEinstellungen {
  final String? rasseDefault;
  final String? beutensystemDefault;
  final int? hoeheDefaultM;
  final int saisonOffsetDefaultTage;
  final String? kanton;
  final String? imkerIdentnummer;
  final num winterfutterZielKg;
  final int anzahlErnten;
  final String sommerbehandlungMethode;
  final bool vermehrungAktiv;

  const BetriebsEinstellungen({
    this.rasseDefault,
    this.beutensystemDefault,
    this.hoeheDefaultM,
    this.saisonOffsetDefaultTage = 0,
    this.kanton,
    this.imkerIdentnummer,
    this.winterfutterZielKg = 22,
    this.anzahlErnten = 1,
    this.sommerbehandlungMethode = 'ameisensaeure',
    this.vermehrungAktiv = false,
  });

  /// Legitimer Leerzustand, wenn (noch) keine Zeile existiert.
  const BetriebsEinstellungen.leer() : this();

  factory BetriebsEinstellungen.fromJson(Map<String, dynamic> j) => BetriebsEinstellungen(
        rasseDefault: j['rasse_default'] as String?,
        beutensystemDefault: j['beutensystem_default'] as String?,
        hoeheDefaultM: j['hoehe_default_m'] as int?,
        saisonOffsetDefaultTage: (j['saison_offset_default_tage'] as int?) ?? 0,
        kanton: j['kanton'] as String?,
        imkerIdentnummer: j['imker_identnummer'] as String?,
        winterfutterZielKg: (j['winterfutter_ziel_kg'] as num?) ?? 22,
        anzahlErnten: (j['anzahl_ernten'] as int?) ?? 1,
        sommerbehandlungMethode: (j['sommerbehandlung_methode'] as String?) ?? 'ameisensaeure',
        vermehrungAktiv: (j['vermehrung_aktiv'] as bool?) ?? false,
      );

  Map<String, dynamic> toUpdateJson() => {
        'saison_offset_default_tage': saisonOffsetDefaultTage,
        'winterfutter_ziel_kg': winterfutterZielKg,
        'anzahl_ernten': anzahlErnten,
        'sommerbehandlung_methode': sommerbehandlungMethode,
        'vermehrung_aktiv': vermehrungAktiv,
      };
}
