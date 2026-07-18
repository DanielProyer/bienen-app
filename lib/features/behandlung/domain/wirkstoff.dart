/// Wirkstoff-Whitelist (DB-CHECK) + Anzeige-Labels.
class Wirkstoff {
  static const werte = <String>[
    'ameisensaeure', 'oxalsaeure', 'milchsaeure', 'thymol', 'kombi_os_as', 'sonstige',
  ];
  static const labels = <String, String>{
    'ameisensaeure': 'Ameisensäure',
    'oxalsaeure': 'Oxalsäure',
    'milchsaeure': 'Milchsäure',
    'thymol': 'Thymol',
    'kombi_os_as': 'Kombi OS/AS (z.B. VarroMed)',
    'sonstige': 'Sonstige',
  };
}

/// Anwendungsart-Whitelist (DB-CHECK) + Labels. `ohneChemie` steuert Menge-/Präparat-Pflicht + Bio-Zweig.
class Anwendungsart {
  static const werte = <String>[
    'traeufeln', 'spruehen', 'verdampfen', 'dispenser_verdunster',
    'streifen_langzeit', 'schwammtuch', 'biotechnik', 'waermebehandlung',
  ];
  static const labels = <String, String>{
    'traeufeln': 'Träufeln',
    'spruehen': 'Sprühen',
    'verdampfen': 'Verdampfen/Sublimieren',
    'dispenser_verdunster': 'Dispenser/Verdunster',
    'streifen_langzeit': 'Streifen (Langzeit)',
    'schwammtuch': 'Schwammtuch',
    'biotechnik': 'Biotechnik (Drohnenschnitt/TBE)',
    'waermebehandlung': 'Wärmebehandlung',
  };
  static const ohneChemie = <String>{'biotechnik', 'waermebehandlung'};
}

enum BioBewertung { konform, warnung }

/// Bio-Konformität: Biotechnik/Wärme = konform (keine Chemie); organische Säuren + Thymol +
/// Kombi = konform (Recherche 15 §5/§7.5 — Thymovar/ApiLifeVAR sind erlaubte Bio-Mittel; die
/// 5 mg/kg sind ein Wachs-Rückstandsgrenzwert, keine Aussage zur Behandlung); nur `sonstige` = Warnung.
BioBewertung bioKonformitaet(String wirkstoff, String anwendungsart) {
  if (Anwendungsart.ohneChemie.contains(anwendungsart)) return BioBewertung.konform;
  const konform = {'ameisensaeure', 'oxalsaeure', 'milchsaeure', 'kombi_os_as', 'thymol'};
  return konform.contains(wirkstoff) ? BioBewertung.konform : BioBewertung.warnung;
}
