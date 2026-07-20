/// Durchsicht-Merkmal (Toggle-key bzw. 'flag_*') → Wissens-key. Nur belegte Merkmale bekommen ein ⓘ.
/// 'mittelwand' und 'leer' haben (v1) keinen Eintrag → kein ⓘ.
const kDurchsichtWissen = <String, String>{
  'brut': 'brut_offen_verdeckelt',
  'pollen': 'pollen',
  'futter': 'futter_nektar',
  'honig': 'futter_nektar',
  'baurahmen': 'baurahmen_drohnen',
  'flag_koenigin': 'koenigin_finden',
  'flag_weiselzelle': 'weiselzelle',
  'flag_stifte': 'stifte',
};
