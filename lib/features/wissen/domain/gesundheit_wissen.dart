/// Krankheit-Key (krankheit.dart) → Wissens-key. varroa/viren reusen den Varroa-Eintrag.
/// Nicht gemappte Keys (wachsmotte, braula, tracheenmilbe, vergiftung,
/// kleiner_beutenkaefer, tropilaelaps, sonstige) → kein ⓘ.
const kKrankheitWissen = <String, String>{
  'afb': 'afb',
  'efb': 'efb',
  'kalkbrut': 'kalkbrut',
  'steinbrut': 'steinbrut',
  'sackbrut': 'sackbrut',
  'ruhr': 'ruhr_nosema',
  'nosema': 'ruhr_nosema',
  'vespa_velutina': 'vespa_velutina',
  'varroa': 'varroa_milbe',
  'viren': 'varroa_milbe',
};
