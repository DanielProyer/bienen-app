import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
  WissensKategorie(key: 'varroa', titel: 'Varroa', icon: 'bug'),
];

const kWissensKatalog = <WissensEintrag>[
  WissensEintrag(
    key: 'stifte', titel: 'Stifte erkennen', kategorie: 'durchsicht',
    kurzinfo: 'Frische Eier sind schlanke, ~1,5 mm lange „Reiskörner", die senkrecht am Zellboden stehen. '
        'Sichtbare Stifte = die Königin hat vor höchstens 3 Tagen gelegt.',
    skizze: 'assets/wissen/stifte.svg',
    mehr: [WissensLink(label: 'Bienenvolk & Eilage', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md')],
    verwandte: ['koenigin_finden', 'brut_offen_verdeckelt', 'weiselzelle'],
    stichworte: ['ei', 'eier', 'reiskorn', 'gelege', 'stift'],
  ),
  WissensEintrag(
    key: 'brut_offen_verdeckelt', titel: 'Brutbild deuten', kategorie: 'durchsicht',
    kurzinfo: 'Gesund: flach, geschlossen, lückenlos verdeckelt. Löcher/„Schrotschuss" = mögliche Störung. '
        'Buckelbrut (einzeln hochgewölbte Deckel auf Arbeiterzellen, verstreut, mehrere Eier pro Zelle) = '
        'drohnenbrütig/weisellos → rasch handeln. Gewollte Drohnen-Buckelzellen stehen dagegen im Baurahmen.',
    skizze: 'assets/wissen/brutbild.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Brut', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Völkervermehrung (Weisellosigkeit)', rechercheAsset: 'assets/recherche/13_Voelkervermehrung.md'),
      WissensLink(label: 'Bienengesundheit', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md'),
    ],
    verwandte: ['stifte', 'weiselzelle', 'baurahmen_drohnen'],
    stichworte: ['brutnest', 'verdeckelt', 'buckelbrut', 'drohnenmuetterchen', 'schrotschuss'],
  ),
  WissensEintrag(
    key: 'pollen', titel: 'Pollen & Bienenbrot', kategorie: 'durchsicht',
    kurzinfo: 'Bunte, matt-glänzende, fest eingestampfte Zellen — meist im Kranz rund um das Brutnest. '
        'Zeichen für Sammeltätigkeit und gute Ernährung.',
    skizze: 'assets/wissen/pollen.svg',
    mehr: [WissensLink(label: 'Bienenvolk & Ernährung', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md')],
    verwandte: ['futter_nektar'],
    stichworte: ['bienenbrot', 'perga', 'pollenkranz'],
  ),
  WissensEintrag(
    key: 'futter_nektar', titel: 'Futter & Nektar', kategorie: 'durchsicht',
    kurzinfo: 'Offener Nektar ist glänzend und flüssig, oben in der Wabe. Reifer Honig ist weiß verdeckelt. '
        'Die Menge grob = Anzahl gefüllter Waben.',
    skizze: 'assets/wissen/futter.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Vorräte', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Honig-Ernte & Qualität', rechercheAsset: 'assets/recherche/16_Honig_Ernte_Qualitaet_Vermarktung.md'),
    ],
    verwandte: ['pollen'],
    stichworte: ['honig', 'nektar', 'futter', 'vorrat'],
  ),
  WissensEintrag(
    key: 'weiselzelle', titel: 'Weiselzelle deuten', kategorie: 'durchsicht',
    kurzinfo: 'Schwarmzellen hängen am Wabenrand/-unterkante, oft mehrere → Schwarmstimmung. '
        'Nachschaffungszellen sitzen in der Wabenfläche → das Volk zieht eine Ersatz-Königin (Weisellosigkeit).',
    skizze: 'assets/wissen/weiselzelle.svg',
    mehr: [
      WissensLink(label: 'Völkervermehrung & Schwarm', rechercheAsset: 'assets/recherche/13_Voelkervermehrung.md'),
      WissensLink(label: 'Vermehrung/Jungvolk (BGD)', rechercheAsset: 'assets/recherche/25_Vermehrung_Jungvolkbildung_BGD.md'),
    ],
    verwandte: ['koenigin_finden', 'stifte', 'brut_offen_verdeckelt'],
    stichworte: ['schwarmzelle', 'nachschaffung', 'weiselnapf', 'schwarm'],
  ),
  WissensEintrag(
    key: 'koenigin_finden', titel: 'Königin finden', kategorie: 'durchsicht',
    kurzinfo: 'Länger, glänzender Hinterleib, ruhige Bewegung — meist im Bienenpulk auf offener Brut. '
        'Systematisch Wabe für Wabe suchen, dort, wo Stifte und junge Brut sind.',
    skizze: 'assets/wissen/koenigin.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Königin', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Königinnenzucht', rechercheAsset: 'assets/recherche/12_Koeniginnenzucht.md'),
    ],
    verwandte: ['stifte', 'weiselzelle'],
    stichworte: ['weisel', 'koenigin', 'majestaet'],
  ),
  WissensEintrag(
    key: 'baurahmen_drohnen', titel: 'Baurahmen lesen', kategorie: 'durchsicht',
    kurzinfo: 'Im Baurahmen bauen die Bienen Drohnenzellen (hochgewölbte Buckelzellen). '
        'Verdeckelte Drohnenbrut ausschneiden = biotechnische Varroa-Reduktion (die Milbe bevorzugt Drohnenbrut).',
    skizze: 'assets/wissen/baurahmen.svg',
    mehr: [
      WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md'),
      WissensLink(label: 'Varroa-Behandlung (BGD)', rechercheAsset: 'assets/recherche/22_Varroa_Behandlungskonzept_BGD.md'),
    ],
    verwandte: ['weiselzelle', 'brut_offen_verdeckelt', 'varroa_milbe'],
    stichworte: ['drohnenbrut', 'drohnenrahmen', 'varroa', 'biotechnik'],
  ),
  WissensEintrag(
    key: 'varroa_milbe', titel: 'Varroamilbe erkennen', kategorie: 'varroa',
    kurzinfo: 'Rotbraun, ~1,6 mm breit / 1,1 mm lang (als Punkt mit blossem Auge sichtbar). Sitzt phoretisch zwischen den Bauchsegmenten '
        'der Biene oder — geschützt — in der verdeckelten Brut (Drohnenbrut wird 8–10× bevorzugt). Der eigentliche '
        'Schaden sind übertragene Viren (v. a. DWV → verkrüppelte Flügel), die geschädigte Winterbienen erzeugen — '
        'daran stirbt das Volk.',
    skizze: 'assets/wissen/varroa_milbe.svg',
    mehr: [
      WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md'),
      WissensLink(label: 'Varroa-Behandlung (BGD)', rechercheAsset: 'assets/recherche/22_Varroa_Behandlungskonzept_BGD.md'),
    ],
    verwandte: ['gemuelldiagnose', 'baurahmen_drohnen'],
    stichworte: ['milbe', 'destructor', 'dwv', 'virus', 'varroa'],
  ),
  WissensEintrag(
    key: 'gemuelldiagnose', titel: 'Gemülldiagnose (Windel)', kategorie: 'varroa',
    kurzinfo: 'Eingefettete Varroa-Windel auf den Gitterboden schieben, 3–7 Tage liegen lassen, gefallene Milben '
        'zählen ÷ Tage = natürlicher Milbenfall pro Tag. Schwellen saisonabhängig (grob Juli >10, August >25 '
        'Milben/Tag = sofort behandeln). Bienenschonender Dauer-Trend — auf 1570 m die Kalenderzeilen ~4–6 Wochen '
        'später lesen (immer messen, nicht nach Datum gehen).',
    skizze: 'assets/wissen/gemuelldiagnose.svg',
    mehr: [WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md')],
    verwandte: ['varroa_milbe', 'puderzucker_auswaschung'],
    stichworte: ['windel', 'gemuell', 'totenfall', 'milbenfall', 'monitoring', 'diagnose'],
  ),
  WissensEintrag(
    key: 'puderzucker_auswaschung', titel: 'Puderzucker & Auswaschung', kategorie: 'varroa',
    kurzinfo: '~50 g (~300) Bienen aus dem Brutraum (NICHT von der Königinnenwabe) in ein Sieb-Glas. Puderzucker '
        '(Bienen überleben) oder Alkohol/Auswaschung (genauer, aber tödlich) → die Milben lösen sich, ausschütteln '
        'und zählen. Befall % = Milben ÷ Bienen × 100 (3 Milben/300 = 1 %). Über ~3 % im Sommer ist kritisch.',
    skizze: 'assets/wissen/puderzucker.svg',
    mehr: [WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md')],
    verwandte: ['gemuelldiagnose', 'varroa_milbe'],
    stichworte: ['puderzucker', 'auswaschung', 'alkoholwaschung', 'befall', 'prozent', 'diagnose'],
  ),
  WissensEintrag(
    key: 'ameisensaeure', titel: 'Ameisensäure (Sommer)', kategorie: 'varroa',
    kurzinfo: 'Die einzige organische Säure, die als Gas (teilweise) unter den Brutdeckel wirkt → Kern der '
        'Sommerbehandlung nach der Ernte. Wirkung über Verdunstung, stark temperaturabhängig (~15–25 °C) — auf '
        '1570 m das schwache Glied (kühle Nächte). Nur ohne Honigraum. Stark ätzend: säurefeste Handschuhe, '
        'Schutzbrille, im Freien umfüllen, Dämpfe nicht einatmen. Dosis/System = Richtwert — Etikett/Merkblatt beachten.',
    skizze: 'assets/wissen/ameisensaeure.svg',
    mehr: [
      WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md'),
      WissensLink(label: 'Varroa-Behandlung (BGD)', rechercheAsset: 'assets/recherche/22_Varroa_Behandlungskonzept_BGD.md'),
    ],
    verwandte: ['oxalsaeure', 'thymol'],
    stichworte: ['ameisensaeure', 'formivar', 'sommerbehandlung', 'verdunster', 'as'],
  ),
  WissensEintrag(
    key: 'oxalsaeure', titel: 'Oxalsäure (Winter)', kategorie: 'varroa',
    kurzinfo: 'Restentmilbung in der brutfreien Phase — wirkt nur auf Milben AUF den Bienen, nicht unter '
        'Brutdeckeln (Brutfreiheit ist Pflicht). Träufeln: 5–6 ml handwarme Lösung pro besetzte Wabengasse, '
        'max. ~50 ml/Volk, max. 1×/Winter. Höhenlage-Vorteil: die Völker werden früh und zuverlässig brutfrei '
        '(ab Ende Okt/Anfang Nov) → planbar und wirksam. Alternativ Verdampfen (FFP3-Atemschutz zwingend). '
        'Dosis = Richtwert — Etikett/Merkblatt beachten.',
    skizze: 'assets/wissen/oxalsaeure.svg',
    mehr: [WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md')],
    verwandte: ['ameisensaeure', 'milchsaeure'],
    stichworte: ['oxalsaeure', 'oxuvar', 'traeufeln', 'verdampfen', 'sublimieren', 'winterbehandlung', 'brutfrei'],
  ),
  WissensEintrag(
    key: 'milchsaeure', titel: 'Milchsäure (Ableger)', kategorie: 'varroa',
    kurzinfo: 'Die sanfteste organische Säure — für kleine, brutfreie Einheiten (Kunstschwarm, frischer Ableger, '
        'Jungvolk). Wirkt nur auf phoretische Milben. ~8 ml Milchsäure 15 % je Wabenseite auf die bienenbesetzte '
        'Wabe sprühen (Waben einzeln ziehen). Bienen- und brutschonend → milbenarmer Start für jedes neue Volk. '
        'Dosis = Richtwert — Etikett/Merkblatt beachten.',
    skizze: 'assets/wissen/milchsaeure.svg',
    mehr: [WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md')],
    verwandte: ['oxalsaeure'],
    stichworte: ['milchsaeure', 'ableger', 'kunstschwarm', 'spruehen', 'jungvolk'],
  ),
  WissensEintrag(
    key: 'thymol', titel: 'Thymol (Sommer-Alternative)', kategorie: 'varroa',
    kurzinfo: 'Bio-konformes ätherisches Öl (Thymovar, ApiLife VAR) als Verdunstungsplättchen. Wirkt nur auf '
        'phoretische Milben, dafür über eine lange Standzeit (2 Anwendungen à 3–4 Wochen), Optimum 20–25 °C. '
        'KEIN Notfallmittel für stark befallene Völker (dafür Ameisensäure oder Brutentnahme). Nur ohne Honigraum; '
        'kann Honig-/Wachsgeschmack beeinflussen. Plättchenzahl/Standzeit = Richtwert — Gebrauchsanweisung beachten.',
    skizze: 'assets/wissen/thymol.svg',
    mehr: [WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md')],
    verwandte: ['ameisensaeure'],
    stichworte: ['thymol', 'thymovar', 'apilife', 'aetherisches oel'],
  ),
];

WissensEintrag? wissenVon(String? key) {
  if (key == null) return null;
  for (final e in kWissensKatalog) {
    if (e.key == key) return e;
  }
  return null; // KEIN firstWhere ohne orElse — Null-Kontrakt trägt den WissenInfoButton
}

Iterable<WissensKategorie> belegteKategorien({
  List<WissensKategorie> kategorien = kWissensKategorien,
  List<WissensEintrag> katalog = kWissensKatalog,
}) => kategorien.where((k) => katalog.any((e) => e.kategorie == k.key));

List<WissensEintrag> eintraegeDerKategorie(String kategorieKey,
        {List<WissensEintrag> katalog = kWissensKatalog}) =>
    katalog.where((e) => e.kategorie == kategorieKey).toList();

String _normalisiere(String s) => s.toLowerCase()
    .replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');

List<WissensEintrag> sucheWissen(String query, {List<WissensEintrag> katalog = kWissensKatalog}) {
  final q = _normalisiere(query.trim());
  if (q.isEmpty) return const [];
  return katalog.where((e) =>
      _normalisiere(e.titel).contains(q) ||
      _normalisiere(e.kurzinfo).contains(q) ||
      e.stichworte.any((s) => _normalisiere(s).contains(q))).toList();
}
