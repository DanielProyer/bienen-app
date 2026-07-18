enum Ampel { gruen, gelb, rot, keinRichtwert }

/// Milben pro Tag (Gemülldiagnose) = milben_gesamt / messdauer_tage. Null-sicher.
double? milbenProTag(num? milbenGesamt, int? messdauerTage) {
  if (milbenGesamt == null || messdauerTage == null || messdauerTage <= 0) return null;
  return milbenGesamt / messdauerTage;
}

/// Befall in % (Puderzucker/Auswaschung) = milben_gesamt / bienen_probe * 100. Null-sicher.
double? befallProzent(num? milbenGesamt, int? bienenProbe) {
  if (milbenGesamt == null || bienenProbe == null || bienenProbe <= 0) return null;
  return milbenGesamt / bienenProbe * 100;
}

/// Saisonale Ampel für natürlichen Milbenfall/Tag (Gemülldiagnose). Fachdefaults Recherche 15 §4,
/// universell/mandantenfähig (F4 macht sie pro Betrieb konfigurierbar). Nov–Apr: kein Richtwert
/// (brutfrei/Cluster — Fall = Erfolgskontrolle einer Winterbehandlung, KEIN Behandlungsanlass).
Ampel ampelGemuell(double? milbenProTag, int monat) {
  if (milbenProTag == null) return Ampel.keinRichtwert;
  // [gruenMax (exkl.), gelbMax (inkl.)]; darüber = rot.
  const schwellen = <int, List<double>>{
    5: [5, 10], 6: [5, 10], 7: [5, 10], // Mai/Jun = Juli-Anker (Richtwert); Juli = Recherche
    8: [10, 25], // August = Recherche
    9: [15, 25], // September = Recherche
    10: [5, 10], // Oktober = konservativer Anker (Winterbienen)
  };
  final s = schwellen[monat];
  if (s == null) return Ampel.keinRichtwert; // Nov–Apr
  if (milbenProTag < s[0]) return Ampel.gruen;
  if (milbenProTag <= s[1]) return Ampel.gelb;
  return Ampel.rot;
}

/// Ampel für Befall-% (Puderzucker/Auswaschung). Richtwert Recherche 15: ~1 % Schwelle, >3 % klar behandeln.
Ampel ampelPuderzucker(double? befallProzent) {
  if (befallProzent == null) return Ampel.keinRichtwert;
  if (befallProzent < 1) return Ampel.gruen;
  if (befallProzent <= 3) return Ampel.gelb;
  return Ampel.rot;
}

/// Wählt die methodengerechte Ampel für eine Kontrolle (Gemüll → Milben/Tag, sonst → Befall-%).
Ampel ampelFuerKontrolle({
  required String methode,
  required num milbenGesamt,
  int? messdauerTage,
  int? bienenProbe,
  required int monat,
}) {
  if (methode == 'gemuell') return ampelGemuell(milbenProTag(milbenGesamt, messdauerTage), monat);
  return ampelPuderzucker(befallProzent(milbenGesamt, bienenProbe));
}
