# Wissensdatenbank Zyklus 2 — Kategorie Varroa + Andock Behandlung/Diagnose

**Datum:** 2026-07-20 · **Track:** App · **Baut auf:** Modul 4.21 Zyklus 1 (v1.21.0). Kein neues DB/Migration — reine Katalog-Erweiterung + Andock. Fachquelle: `assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md` (+ `22_Varroa_Behandlungskonzept_BGD.md`).

Neue Kategorie `varroa` (7 Einträge) + ⓘ-Andock in der Milbendiagnose (`kontrolle_form_page`, methode) und im Behandlungs-Journal (`behandlung_form_page`, wirkstoff), je **ein dynamisches ⓘ pro Feld** (öffnet den Eintrag zum aktuell gewählten Wert).

---

## 1. Katalog-Erweiterung (`lib/features/wissen/domain/wissen_katalog.dart`)

Kategorie ergänzen:
```dart
const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
  WissensKategorie(key: 'varroa', titel: 'Varroa', icon: 'bug'),
];
```

7 Einträge an `kWissensKatalog` anhängen (zeichengenau):
```dart
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
```

Verwandte-Querlink im **Durchsicht**-Eintrag `baurahmen_drohnen` ergänzen (Varroa-Biotechnik): `verwandte: ['weiselzelle', 'brut_offen_verdeckelt', 'varroa_milbe']`.

## 2. Andock-Maps (`lib/features/wissen/domain/behandlung_wissen.dart`, neu)

```dart
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
```

## 3. Andock in den Formularen (je EIN dynamisches ⓘ pro Feld)

- `kontrolle_form_page.dart`: neben dem Methoden-Label/den ChoiceChips ein `WissenInfoButton(wissenKey: kVarroaMethodeWissen[_methode] ?? '')` (öffnet den Eintrag zur aktuell gewählten Methode). Import `durchsicht_wissen.dart` NICHT nötig — `behandlung_wissen.dart` + `wissen_info_button.dart`.
- `behandlung_form_page.dart`: neben dem Wirkstoff-Dropdown (`_wirkstoff`, Zeile ~124) ein `WissenInfoButton(wissenKey: kBehandlungWirkstoffWissen[_wirkstoff] ?? '')`. Da der Dropdown `setState` auslöst, aktualisiert sich das ⓘ automatisch.

`WissenInfoButton` rendert bei leerem/unbekanntem key nichts (`wissenVon('') == null`) — unbelegte Werte (kombi_os_as, sonstige) sind damit sauber abgedeckt.

## 4. SVG-Skizzen (`assets/wissen/`, viewBox 0 0 240 160, Stil wie Zyklus 1; Milbe = rotbraun #8a3b1a)

`varroa_milbe.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <ellipse cx="110" cy="70" rx="52" ry="30" fill="#F0C24A" stroke="#633806" stroke-width="2"/>
  <g stroke="#633806" stroke-width="2"><line x1="96" y1="44" x2="96" y2="96"/><line x1="118" y1="42" x2="118" y2="98"/><line x1="140" y1="46" x2="140" y2="94"/></g>
  <circle cx="64" cy="66" r="10" fill="#633806"/>
  <ellipse cx="138" cy="80" rx="11" ry="8" fill="#8a3b1a" stroke="#3d1c0c" stroke-width="1.5"/>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="140">Milbe (rotbraun, ~1 mm) auf der Biene</text></g>
</svg>
```

`gemuelldiagnose.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="30" y="24" width="180" height="86" rx="4" fill="#FBF6E9" stroke="#633806" stroke-width="2"/>
  <g stroke="#d8c9a0" stroke-width="1"><line x1="70" y1="24" x2="70" y2="110"/><line x1="110" y1="24" x2="110" y2="110"/><line x1="150" y1="24" x2="150" y2="110"/><line x1="190" y1="24" x2="190" y2="110"/><line x1="30" y1="53" x2="210" y2="53"/><line x1="30" y1="81" x2="210" y2="81"/></g>
  <g fill="#8a3b1a"><circle cx="52" cy="40" r="3.5"/><circle cx="96" cy="66" r="3.5"/><circle cx="130" cy="44" r="3.5"/><circle cx="168" cy="70" r="3.5"/><circle cx="120" cy="96" r="3.5"/><circle cx="76" cy="92" r="3.5"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="140">Windel: Milben ÷ Tage = Fall/Tag</text></g>
</svg>
```

`puderzucker.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="86" y="20" width="68" height="16" rx="3" fill="#d8c9a0" stroke="#633806" stroke-width="2"/>
  <path d="M88 36 h64 v76 a8 8 0 0 1 -8 8 h-48 a8 8 0 0 1 -8 -8 z" fill="#FBF6E9" stroke="#633806" stroke-width="2"/>
  <g fill="#F0C24A" stroke="#633806" stroke-width="1"><ellipse cx="108" cy="78" rx="9" ry="6"/><ellipse cx="132" cy="90" rx="9" ry="6"/><ellipse cx="118" cy="104" rx="9" ry="6"/></g>
  <g fill="#8a3b1a"><circle cx="112" cy="70" r="2.6"/><circle cx="140" cy="82" r="2.6"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="146">Befall % = Milben ÷ Bienen × 100</text></g>
</svg>
```

`ameisensaeure.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="46" y="52" width="148" height="70" rx="4" fill="none" stroke="#633806" stroke-width="3"/>
  <rect x="150" y="40" width="34" height="46" rx="3" fill="#E8EDF2" stroke="#633806" stroke-width="2"/>
  <g stroke="#3d8ac0" stroke-width="2" stroke-linecap="round" fill="none"><path d="M110 108 q-6 -16 4 -30 q8 -12 2 -26"/><path d="M132 110 q-6 -16 4 -30 q8 -12 2 -26"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="146">verdunstet als Gas in die Brut</text></g>
</svg>
```

`oxalsaeure.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="2" fill="none"><line x1="70" y1="30" x2="70" y2="118"/><line x1="98" y1="30" x2="98" y2="118"/><line x1="126" y1="30" x2="126" y2="118"/><line x1="154" y1="30" x2="154" y2="118"/></g>
  <ellipse cx="112" cy="92" rx="40" ry="20" fill="#F0C24A" stroke="#633806" stroke-width="1.5" opacity="0.7"/>
  <rect x="104" y="14" width="16" height="30" rx="3" fill="#E8EDF2" stroke="#633806" stroke-width="2"/>
  <g stroke="#3d8ac0" stroke-width="2.5" stroke-linecap="round"><line x1="112" y1="46" x2="112" y2="66"/></g>
  <circle cx="112" cy="72" r="3" fill="#3d8ac0"/>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="146">träufeln in die Wabengasse · brutfrei</text></g>
</svg>
```

`milchsaeure.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="70" y="24" width="90" height="96" rx="4" fill="#F0C24A" stroke="#633806" stroke-width="2" opacity="0.6"/>
  <rect x="176" y="52" width="20" height="30" rx="3" fill="#E8EDF2" stroke="#633806" stroke-width="2"/>
  <g fill="#3d8ac0"><circle cx="168" cy="60" r="2"/><circle cx="160" cy="66" r="2"/><circle cx="164" cy="72" r="2"/><circle cx="154" cy="60" r="2"/><circle cx="150" cy="70" r="2"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="146">sprühen · brutfreie Ableger</text></g>
</svg>
```

`thymol.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="46" y="40" width="148" height="80" rx="4" fill="none" stroke="#633806" stroke-width="3"/>
  <rect x="96" y="30" width="48" height="20" rx="3" fill="#9BB43A" stroke="#3B6D11" stroke-width="2"/>
  <g stroke="#3B6D11" stroke-width="2" stroke-linecap="round" fill="none"><path d="M112 62 q-5 -8 3 -16"/><path d="M128 64 q-5 -8 3 -16"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="120" y="146">Plättchen · lange, milde Standzeit</text></g>
</svg>
```

## 5. Tests
- `wissen_katalog_test.dart` läuft unverändert grün (prüft neue Skizzen-Existenz, rechercheAsset-Existenz [15/22 vorhanden], verwandte-Auflösung — inkl. `baurahmen_drohnen↔varroa_milbe`).
- Neuer Test `behandlung_wissen_test.dart`: jeder Wert in `kVarroaMethodeWissen` + `kBehandlungWirkstoffWissen` löst via `wissenVon` auf; jeder Methode-Schlüssel ∈ {gemuell,puderzucker,auswaschung}; jeder Wirkstoff-Schlüssel ∈ `Wirkstoff.werte` (aus `wirkstoff.dart`).
- `belegteKategorien` enthält jetzt auch `varroa` (2 Kacheln in `/wissen`).

## 6. Deploy
Version-Bump `1.22.0+43`, `flutter analyze`+`flutter test` grün → `bash deploy.sh`. Kein Migrations-Schritt.
