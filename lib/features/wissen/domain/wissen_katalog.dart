import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
  WissensKategorie(key: 'varroa', titel: 'Varroa', icon: 'bug'),
  WissensKategorie(key: 'krankheit', titel: 'Krankheiten', icon: 'health'),
  WissensKategorie(key: 'fuetterung', titel: 'Fütterung', icon: 'droplet'),
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
        'daran stirbt das Volk. Hinweis: nicht alle Bienenviren sind varroagekoppelt — die Chronische '
        'Bienenparalyse (CBPV: zitternde, haarlose schwarze Bienen) entsteht durch Stress/Dichte.',
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
  WissensEintrag(
    key: 'afb', titel: 'Amerikanische Faulbrut (AFB)', kategorie: 'krankheit',
    kurzinfo: 'Meldepflichtig schon bei Verdacht. Erkennen: eingesunkene, durchlöcherte, feuchte Zelldeckel in der '
        'VERDECKELTEN Brut; ein Streichholz zieht aus der Zelle einen braunen, fadenziehenden Schleim '
        '(Streichholzprobe); modriger Geruch; lückiges Brutbild. Volk geschlossen halten, NICHTS umhängen — der '
        'Bieneninspektor nimmt die amtliche Probe — keine Eigenprobe einsenden (Details siehe Melde-Banner im Formular).',
    skizze: 'assets/wissen/afb.svg',
    mehr: [
      WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md'),
      WissensLink(label: 'Krankheiten/Schädlinge (BGD)', rechercheAsset: 'assets/recherche/23_Krankheiten_Schaedlinge_BGD.md'),
    ],
    verwandte: ['sackbrut', 'efb'],
    stichworte: ['afb', 'faulbrut', 'amerikanisch', 'streichholzprobe', 'brut'],
  ),
  WissensEintrag(
    key: 'efb', titel: 'Europäische Sauerbrut (EFB)', kategorie: 'krankheit',
    kurzinfo: 'Meldepflichtig schon bei Verdacht. Erkennen: verkrümmte, vergilbte, in der Zelle verrutschte OFFENE '
        'Larven (vor der Verdeckelung — Unterschied zur AFB in der verdeckelten Brut); lückiges Brutbild; '
        'säuerlicher Geruch. Volk geschlossen halten, Inspektor melden (siehe Melde-Banner).',
    skizze: 'assets/wissen/efb.svg',
    mehr: [
      WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md'),
      WissensLink(label: 'Krankheiten/Schädlinge (BGD)', rechercheAsset: 'assets/recherche/23_Krankheiten_Schaedlinge_BGD.md'),
    ],
    verwandte: ['afb', 'sackbrut'],
    stichworte: ['efb', 'sauerbrut', 'europaeisch', 'offene brut'],
  ),
  WissensEintrag(
    key: 'kalkbrut', titel: 'Kalkbrut', kategorie: 'krankheit',
    kurzinfo: 'Nicht meldepflichtig, meist beherrschbar. Erkennen: mumifizierte, kreideweiße bis graue, HARTE Larven '
        '(„Kalkstücke") in den Zellen und vor der Beute; oft ein „Klappern" der losen Mumien auf dem Bodenbrett. '
        'Begünstigt durch feucht-kühlen Stand + schwaches Volk. Gegensteuern: Volk stärken, junge Königin, '
        'Wabenerneuerung, trockener/warmer Standort. NICHT mit Steinbrut verwechseln (grün-gelbliche, '
        'humanpathogene Mumien → FFP-Maske!).',
    skizze: 'assets/wissen/kalkbrut.svg',
    mehr: [WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md')],
    verwandte: ['sackbrut', 'steinbrut'],
    stichworte: ['kalkbrut', 'mumie', 'pilz', 'ascosphaera', 'kreideweiss'],
  ),
  WissensEintrag(
    key: 'steinbrut', titel: 'Steinbrut (Aspergillus)', kategorie: 'krankheit',
    kurzinfo: 'ACHTUNG humanpathogen (Atemwege). Erkennen: harte Mumien wie bei Kalkbrut, aber grün-gelblich '
        'bepudert/verpilzt (Aspergillus-Sporen). Selten. ARBEITSSCHUTZ: nur mit Handschuhen + FFP2/FFP3-Maske '
        'anfassen, Sporen NICHT einatmen, befallene Waben entsorgen. Verwechslung mit der harmlosen Kalkbrut '
        '(kreideweiße Mumien) — im Zweifel Schutz tragen.',
    skizze: 'assets/wissen/steinbrut.svg',
    mehr: [WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md')],
    verwandte: ['kalkbrut'],
    stichworte: ['steinbrut', 'aspergillus', 'schimmel', 'ffp', 'arbeitsschutz', 'mumie'],
  ),
  WissensEintrag(
    key: 'sackbrut', titel: 'Sackbrut', kategorie: 'krankheit',
    kurzinfo: 'Nicht meldepflichtig — aber AFB-VERWECHSLUNGSGEFAHR. Erkennen: einzelne gestreckte, sackförmige '
        '(flüssigkeitsgefüllte) Larven mit hochgezogenem Köpfchen. Abgrenzung: die Fadenzugprobe zieht bei Sackbrut '
        'KEINEN Faden (bei AFB schon). Bei Unsicherheit wie AFB behandeln = melden. Sonst: Volk stärken.',
    skizze: 'assets/wissen/sackbrut.svg',
    mehr: [WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md')],
    verwandte: ['afb', 'kalkbrut'],
    stichworte: ['sackbrut', 'sackfoermig', 'verwechslung', 'fadenzugprobe'],
  ),
  WissensEintrag(
    key: 'ruhr_nosema', titel: 'Ruhr & Nosema (Kotspritzer)', kategorie: 'krankheit',
    kurzinfo: 'Erkennen: braune Kotspritzer an Flugloch, Beute und Waben = Durchfall. Ursachen: schlechtes, schwer '
        'verdauliches Winterfutter (hoher Waldhonig-/Melezitose-Anteil), langer Flugunterbruch, oder Nosema '
        '(Darmparasit, sicher nur mikroskopisch '
        'nachweisbar). Gegensteuern: Futterqualität prüfen, Reinigungsflug abwarten, Wabenhygiene, starke Völker; '
        'bei Verdacht Nosema-Probe an BGD/Agroscope.',
    skizze: 'assets/wissen/ruhr_nosema.svg',
    mehr: [WissensLink(label: 'Bienengesundheit (CH)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md')],
    verwandte: [],
    stichworte: ['ruhr', 'durchfall', 'nosema', 'nosemose', 'kotspritzer'],
  ),
  WissensEintrag(
    key: 'vespa_velutina', titel: 'Asiatische Hornisse', kategorie: 'krankheit',
    kurzinfo: 'Meldepflichtige invasive Art. Erkennen: dunkler Körper mit gelben Beinenden und oranger Kopfvorderseite; '
        'rüttelt jagend vor dem Flugloch („Hawking"), um heimkehrende Bienen zu greifen; Nest oft hoch in Bäumen. '
        'Nicht mit der helleren einheimischen Hornisse verwechseln. Nester NICHT selbst entfernen (Spezialisten). '
        'Fund mit Foto + Standort über asiatischehornisse.ch melden.',
    skizze: 'assets/wissen/vespa_velutina.svg',
    mehr: [
      WissensLink(label: 'Asiatische Hornisse', rechercheAsset: 'assets/recherche/24_Asiatische_Hornisse_Vespa_velutina.md'),
      WissensLink(label: 'Meldeportal asiatischehornisse.ch', url: 'https://www.asiatischehornisse.ch'),
    ],
    verwandte: [],
    stichworte: ['vespa', 'velutina', 'asiatische hornisse', 'neobiota', 'raeuber'],
  ),
  WissensEintrag(
    key: 'auffuetterung', titel: 'Auffütterung (Winterfutter)', kategorie: 'fuetterung',
    kurzinfo: 'Baut den Wintervorrat auf — NUR dieser Zweck zählt fürs Winterfutter-Ziel (~20–25 kg/Volk, alpin '
        'eher am oberen Ende). Dickes Futter (Zuckerwasser 3:2 oder Invertsirup) in zügigen, größeren Gaben nach '
        'der letzten Ernte geben, damit die Bienen es einlagern und verdeckeln, BEVOR die Winterbienen-Aufzucht '
        'endet. Auf 1570 m früher dran (kurze Saison). Immer ABENDS und geschlossen füttern — offenes/tags Füttern '
        'löst Räuberei aus und überträgt so Faulbrut.',
    skizze: 'assets/wissen/auffuetterung.svg',
    mehr: [
      WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md'),
      WissensLink(label: 'Bio-Imkerei (Knospe)', rechercheAsset: 'assets/recherche/18_Bio_Imkerei_Knospe_Schweiz.md'),
    ],
    verwandte: ['zuckerwasser', 'invertsirup', 'futterwaben'],
    stichworte: ['auffuettern', 'winterfutter', 'wintervorrat', 'einwintern', 'einfuettern'],
  ),
  WissensEintrag(
    key: 'reizfuetterung', titel: 'Reizfütterung', kategorie: 'fuetterung',
    kurzinfo: 'Kleine Gaben dünnen Zuckerwassers (1:1) im Vorfrühling regen die Königin zur Bruttätigkeit an — es '
        'geht ums Signal „Tracht", NICHT um Vorrat. Sparsam und nur bei Bedarf: kann Räuberei auslösen und, sobald '
        'Tracht einsetzt oder der Honigraum aufliegt, in den Honig gelangen (Honigreinheit!). Bei ohnehin starken '
        'Völkern meist unnötig.',
    skizze: 'assets/wissen/reizfuetterung.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['notfuetterung', 'zuckerwasser'],
    stichworte: ['reizfuettern', 'anregen', 'brut', 'fruehjahr', 'reizen'],
  ),
  WissensEintrag(
    key: 'notfuetterung', titel: 'Notfütterung', kategorie: 'fuetterung',
    kurzinfo: 'Akute Futterknappheit — das Volk droht zu verhungern: die Beute ist beim Anheben auffällig leicht, '
        'keine Vorräte in den Randwaben, teilnahmslose Bienen, im Extremfall tote Bienen kopfüber in leeren Zellen. '
        'SOFORT Futter geben: bei Kälte Futterteig oder Futterwaben direkt an die Wintertraube, sonst Sirup. Nie mit '
        'aufgesetztem Honigraum.',
    skizze: 'assets/wissen/notfuetterung.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['futterteig', 'reizfuetterung'],
    stichworte: ['notfuettern', 'verhungern', 'hunger', 'futterknappheit', 'futterabriss'],
  ),
  WissensEintrag(
    key: 'zuckerwasser', titel: 'Zuckerwasser (1:1 & 3:2)', kategorie: 'fuetterung',
    kurzinfo: 'Selbst angesetzt aus weißem Kristallzucker + Wasser. 1:1 (dünn, 1 Teil Zucker : 1 Teil Wasser) = '
        'Reizfütterung/Anfüttern im Frühjahr. 3:2 (dick, 3 Teile Zucker : 2 Teile Wasser nach Gewicht) = '
        'Winterfutter — je dicker, desto weniger müssen die Bienen eindicken. Nur weißen Haushaltszucker, KEINEN '
        'Roh-/Braunzucker (unverdaulicher Ballast → Ruhr). Bio: nur biozertifizierter Zucker.',
    skizze: 'assets/wissen/zuckerwasser.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['invertsirup', 'auffuetterung'],
    stichworte: ['zuckerwasser', 'zuckersirup', '1:1', '3:2', 'kristallzucker', 'sirup'],
  ),
  WissensEintrag(
    key: 'invertsirup', titel: 'Invertsirup (Apiinvert)', kategorie: 'fuetterung',
    kurzinfo: 'Gebrauchsfertiger, bereits invertierter Sirup (z. B. Apiinvert, Ambrosia). Vorteil: kein Ansetzen, '
        'bienenschonend, gut lagerbar, geringes Risiko unverdaulichen Ballasts. Ideal für die zügige '
        'Winter-Auffütterung. Etwas teurer als Haushaltszucker; kühl/sauber lagern. Bio: nur biozertifizierter Sirup.',
    skizze: 'assets/wissen/invertsirup.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['zuckerwasser', 'auffuetterung'],
    stichworte: ['invertsirup', 'apiinvert', 'ambrosia', 'fertigfutter', 'sirup'],
  ),
  WissensEintrag(
    key: 'futterteig', titel: 'Futterteig (Fondant)', kategorie: 'fuetterung',
    kurzinfo: 'Fester Zucker-/Fondantteig, oben auf die Rähmchen bzw. ans Futterloch gelegt. Ideal für Not- und '
        'Spätwinter-/Vorfrühlings-Fütterung bei Kälte: die Bienen holen sich die nötige Feuchtigkeit selbst, ohne '
        'dass Flüssigfutter auskühlt. NICHT für den schnellen Aufbau großer Wintervorräte (dafür Sirup).',
    skizze: 'assets/wissen/futterteig.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['notfuetterung'],
    stichworte: ['futterteig', 'fondant', 'teig', 'winter', 'notfutter'],
  ),
  WissensEintrag(
    key: 'futterwaben', titel: 'Futterwaben', kategorie: 'fuetterung',
    kurzinfo: 'Eingelagerte, verdeckelte Futterwaben aus dem eigenen GESUNDEN Bestand — die natürlichste, '
        'bienengerechteste Winterfütterung: kein Ansetzen, direkt neben die Wintertraube gehängt. Voraussetzung: '
        'rückstandsarme Waben aus varroa-kontrollierten, gesunden Völkern; höchstens bis ~4 Wochen vor der '
        'Haupttracht einsetzen (Honigreinheit). Seuchenhygiene beachten — KEINE Waben aus Völkern mit '
        'Faulbrut-Verdacht verschieben.',
    skizze: 'assets/wissen/futterwaben.svg',
    mehr: [WissensLink(label: 'Jahresablauf (alpin)', rechercheAsset: 'assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md')],
    verwandte: ['auffuetterung', 'afb'],
    stichworte: ['futterwaben', 'vorratswaben', 'verdeckelt', 'futterkranz'],
  ),
  WissensEintrag(
    key: 'honig_fuettern', titel: 'Honig füttern', kategorie: 'fuetterung',
    kurzinfo: 'Nur EIGENER, gesunder Honig ist ein natürliches Futter. ACHTUNG: FREMDHONIG (auch Imkerhonig aus dem '
        'Handel) kann Faulbrut-Sporen (AFB) enthalten → strikt vermeiden, er kann den ganzen Stand verseuchen. '
        'Wald-/Honigtauhonig und stark kristallisierender Honig sind als Winterfutter ungeeignet (Kristallisation → '
        'Verhungern trotz Vorrat; hoher Ballast → Ruhr). Für Bio ist eigener Honig zulässig.',
    skizze: 'assets/wissen/honig_fuettern.svg',
    mehr: [
      WissensLink(label: 'Bio-Imkerei (Knospe)', rechercheAsset: 'assets/recherche/18_Bio_Imkerei_Knospe_Schweiz.md'),
      WissensLink(label: 'Bienengesundheit (AFB-Risiko)', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md'),
    ],
    verwandte: ['futterwaben', 'afb'],
    stichworte: ['honig', 'fremdhonig', 'afb', 'sporen', 'faulbrut'],
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
