/// Bewertungs-Achse (bewertung.dart) → Wissens-key. brutbild reust den Durchsicht-Eintrag.
const kBewertungAchseWissen = <String, String>{
  'sanftmut': 'zucht_sanftmut',
  'wabensitz': 'zucht_wabensitz',
  'schwarmtraegheit': 'zucht_schwarmtraegheit',
  'brutbild': 'brut_offen_verdeckelt',   // Reuse Durchsicht-Eintrag (gleiche Beobachtung)
  'volksstaerke': 'zucht_volksstaerke',
  'gesundheit': 'zucht_gesundheit',      // eigener Zucht-Eintrag (Gesundheit als Zuchtmerkmal > Varroa)
};
