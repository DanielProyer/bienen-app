import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
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
    verwandte: ['weiselzelle', 'brut_offen_verdeckelt'],
    stichworte: ['drohnenbrut', 'drohnenrahmen', 'varroa', 'biotechnik'],
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
