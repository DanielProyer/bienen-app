/// Milbendiagnose-Methode (kontrolle_form) → Wissens-key.
const kVarroaMethodeWissen = <String, String>{
  'gemuell': 'gemuelldiagnose',
  'puderzucker': 'puderzucker_auswaschung',
  'auswaschung': 'puderzucker_auswaschung',
};

/// Behandlungs-Wirkstoff (behandlung_form) → Wissens-key. Unbelegte (kombi_os_as/sonstige) → kein ⓘ.
const kBehandlungWirkstoffWissen = <String, String>{
  'ameisensaeure': 'ameisensaeure',
  'oxalsaeure': 'oxalsaeure',
  'milchsaeure': 'milchsaeure',
  'thymol': 'thymol',
};
