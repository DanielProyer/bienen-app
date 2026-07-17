class BetriebsEinstellungen {
  final String? rasseDefault;
  final String? beutensystemDefault;
  final int? hoeheDefaultM;
  final int saisonOffsetDefaultTage;
  final String? kanton;
  final String? imkerIdentnummer;

  const BetriebsEinstellungen({
    this.rasseDefault,
    this.beutensystemDefault,
    this.hoeheDefaultM,
    this.saisonOffsetDefaultTage = 0,
    this.kanton,
    this.imkerIdentnummer,
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
      );
}
