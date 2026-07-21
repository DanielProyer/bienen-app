# Wissensdatenbank Zyklus 5 — Kategorie Zucht + Andock Volk-Bewertung

**Datum:** 2026-07-20 · **Track:** App · **Baut auf:** Modul 4.21 (Zyklus 1-4). Kein DB/Migration. Fachquelle: `assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md`, `12_Koeniginnenzucht.md`, `13_Voelkervermehrung.md`. Kontext: `lib/features/zucht/domain/bewertung.dart` (6 Achsen, kurze Anker-Wörter je Skala 1–4) + `bewertung_form_page.dart` (Achsen-Schleife mit SegmentedButton).

Neue Kategorie `zucht` (5 neue Einträge + 2 Reuse). Andock: je Achse EIN ⓘ im Bewertungs-Formular. `bewertung.dart` hat nur knappe Anker-Wörter (Slider-Labels) — die Wissensschicht ergänzt Bedeutung/Beurteilung/Zucht-Kontext (kein Duplikat).

## 1. Katalog-Erweiterung (`wissen_katalog.dart`)
Kategorie ergänzen:
```dart
  WissensKategorie(key: 'zucht', titel: 'Zucht & Auslese', icon: 'zucht'),
```
Icon-Mapping in `wissen_overview_page.dart` `_katIcons`: `'zucht': Icons.workspace_premium`.

5 Einträge anhängen (zeichengenau):
```dart
  WissensEintrag(
    key: 'zucht_beurteilung', titel: 'Völkerbeurteilung & Auslese', kategorie: 'zucht',
    kurzinfo: 'Die BGD-Völkerbeurteilung bewertet jedes Volk über die Saison auf 6 Merkmalen (Skala 1–4, höher = '
        'besser): Sanftmut, Wabensitz, Schwarmträgheit, Brutbild, Volksstärke, Gesundheit. Zweck: aus den besten '
        'Völkern nachziehen (Zuchtmutter), die schwächsten umweiseln. Immer mehrmals pro Saison und möglichst alle '
        'Völker am selben Tag vergleichen (Tagesform/Wetter beeinflussen die Noten).',
    skizze: 'assets/wissen/zucht_beurteilung.svg',
    mehr: [
      WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md'),
      WissensLink(label: 'Königinnenzucht', rechercheAsset: 'assets/recherche/12_Koeniginnenzucht.md'),
    ],
    verwandte: ['zucht_sanftmut', 'zucht_schwarmtraegheit', 'zucht_volksstaerke'],
    stichworte: ['beurteilung', 'auslese', 'zuchtwert', 'koerung', 'zuchtmutter', 'selektion'],
  ),
  WissensEintrag(
    key: 'zucht_sanftmut', titel: 'Sanftmut bewerten', kategorie: 'zucht',
    kurzinfo: 'Wie ruhig bleibt das Volk beim Öffnen und Arbeiten? Skala von stechlustig (1) über nervös (2) und '
        'sanft (3) bis sehr sanft (4). Bei mildem, trockenem Wetter und ohne Rauch-Überdosis beurteilen (Kälte, '
        'Gewitterstimmung und viel Rauch verfälschen). Sanftmut ist ein zentrales Zuchtziel — aber tagesform-/'
        'wetterabhängig, daher mehrfach über die Saison beurteilen.',
    skizze: 'assets/wissen/zucht_sanftmut.svg',
    mehr: [WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md')],
    verwandte: ['zucht_wabensitz', 'zucht_beurteilung'],
    stichworte: ['sanftmut', 'stechlust', 'temperament', 'wesen'],
  ),
  WissensEintrag(
    key: 'zucht_wabensitz', titel: 'Wabensitz bewerten', kategorie: 'zucht',
    kurzinfo: 'Wie sitzen die Bienen, wenn du die Wabe herausnimmst? Von flüchtig/abtropfend (1) über laufend (2) '
        'und ruhig (3) bis fest sitzend (4). Ruhiges, festes Sitzen erleichtert Durchsicht und Königinnensuche und '
        'gilt als erwünschtes Zuchtmerkmal. Bei ruhiger Wabenführung beurteilen (hektisches Ziehen treibt die '
        'Bienen auf).',
    skizze: 'assets/wissen/zucht_wabensitz.svg',
    mehr: [WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md')],
    verwandte: ['zucht_sanftmut', 'koenigin_finden'],
    stichworte: ['wabensitz', 'sitzverhalten', 'abtropfen', 'laufen'],
  ),
  WissensEintrag(
    key: 'zucht_schwarmtraegheit', titel: 'Schwarmträgheit bewerten', kategorie: 'zucht',
    kurzinfo: 'Wie stark neigt das Volk zum Schwärmen? Von geschwärmt/starker Trieb (1) bis kein Schwarmtrieb (4). '
        'Zeichen: angelegte Weiselzellen, verbautes/verhonigtes Brutnest, „Schwarmstimmung". Fürs Saison-Aggregat '
        'zählt das MINIMUM (ein einziger Schwarm setzt die Note) — Schwarmträgheit ist arbeits- und '
        'ertragsentscheidend und stark züchterisch beeinflussbar.',
    skizze: 'assets/wissen/zucht_schwarmtraegheit.svg',
    mehr: [
      WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md'),
      WissensLink(label: 'Völkervermehrung & Schwarm', rechercheAsset: 'assets/recherche/13_Voelkervermehrung.md'),
    ],
    verwandte: ['weiselzelle', 'zucht_beurteilung'],
    stichworte: ['schwarmtraegheit', 'schwarmtrieb', 'schwarm', 'weiselzelle'],
  ),
  WissensEintrag(
    key: 'zucht_volksstaerke', titel: 'Volksstärke bewerten', kategorie: 'zucht',
    kurzinfo: 'Wie viele Bienen bzw. besetzte Wabengassen hat das Volk — immer im Vergleich zu den anderen Völkern '
        'am selben Tag und passend zur Jahreszeit. Von sehr schwach/Serbel (1) bis stark (4). Wichtig: schwach ≠ '
        'ausmerzen — ein kleines, aber GESUNDES Volk (geschlossenes Brutnest, offenes Futter, erkennbare '
        'Entwicklung) wird VEREINIGT, nicht getötet. Nur ein echtes Serbelvolk (lückenhaftes Brutnest, '
        'Futtermangel, keine Entwicklung) ist Auslese-Kandidat. Immer relativ und zur gleichen Zeit vergleichen.',
    skizze: 'assets/wissen/zucht_volksstaerke.svg',
    mehr: [WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md')],
    verwandte: ['zucht_beurteilung'],
    stichworte: ['volksstaerke', 'serbel', 'bienenmasse', 'staerke'],
  ),
  WissensEintrag(
    key: 'zucht_gesundheit', titel: 'Gesundheit bewerten', kategorie: 'zucht',
    kurzinfo: 'Wie gesund und widerstandsfähig ist das Volk? Von stark belastet/Symptome (1) bis keine '
        'Auffälligkeiten (4). Als Zuchtmerkmal zählt mehr als nur Varroa: geringer Varroabefall/Varroatoleranz, '
        'gutes Hygieneverhalten (Bruthygiene — kranke Brut wird ausgeräumt), Krankheitsfreiheit (keine '
        'löchrige/kranke Brut) und Vitalität/gute Überwinterung. Varroa ist das dominierende Thema — aber ein '
        'sonst kränkelndes, schlecht überwinterndes Volk gehört ebenso zur Auslese.',
    skizze: 'assets/wissen/zucht_gesundheit.svg',
    mehr: [WissensLink(label: 'Zucht & Völkerbeurteilung (BGD)', rechercheAsset: 'assets/recherche/26_Zucht_Voelkerbeurteilung_BGD.md')],
    verwandte: ['varroa_milbe', 'gemuelldiagnose', 'brut_offen_verdeckelt'],
    stichworte: ['gesundheit', 'varroatoleranz', 'hygieneverhalten', 'vitalitaet', 'bruthygiene'],
  ),
```

## 2. Andock-Map (`lib/features/wissen/domain/bewertung_wissen.dart`, neu)
```dart
/// Bewertungs-Achse (bewertung.dart) → Wissens-key. brutbild reust den Durchsicht-Eintrag.
const kBewertungAchseWissen = <String, String>{
  'sanftmut': 'zucht_sanftmut',
  'wabensitz': 'zucht_wabensitz',
  'schwarmtraegheit': 'zucht_schwarmtraegheit',
  'brutbild': 'brut_offen_verdeckelt',   // Reuse Durchsicht-Eintrag (gleiche Beobachtung)
  'volksstaerke': 'zucht_volksstaerke',
  'gesundheit': 'zucht_gesundheit',      // eigener Zucht-Eintrag (Gesundheit als Zuchtmerkmal > Varroa)
};
```

## 3. Andock im Bewertungs-Formular
`lib/features/zucht/presentation/pages/bewertung_form_page.dart`: in der Achsen-Schleife (`for (final a in kBewertungsAchsen) ...[ Text(a.label …), SegmentedButton …, Text(a.anker…) ]`, ~Zeile 104) das `Text(a.label)` durch eine `Row(mainAxisSize: MainAxisSize.min, [Text(a.label…), WissenInfoButton(wissenKey: kBewertungAchseWissen[a.key] ?? '')])` ersetzen. Imports `bewertung_wissen.dart` + `wissen_info_button.dart`. Slider-/Speicherlogik unverändert.

## 4. SVG-Skizzen (`assets/wissen/`, viewBox 0 0 240 160, Stil wie bisher; Biene = amber #E8B84D)

`zucht_beurteilung.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <line x1="30" y1="110" x2="214" y2="110" stroke="#633806" stroke-width="2"/>
  <g stroke="#633806" stroke-width="1">
    <rect x="40" y="70" width="20" height="40" fill="#F0C24A"/>
    <rect x="70" y="52" width="20" height="58" fill="#F0C24A"/>
    <rect x="100" y="34" width="20" height="76" fill="#E8A33D"/>
    <rect x="130" y="60" width="20" height="50" fill="#F0C24A"/>
    <rect x="160" y="84" width="20" height="26" fill="#C9A66B"/>
    <rect x="190" y="46" width="20" height="64" fill="#F0C24A"/>
  </g>
  <text x="110" y="28" text-anchor="middle" font-size="14" fill="#3B6D11">★</text>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">6 Merkmale · beste Völker nachziehen</text></g>
</svg>
```

`zucht_sanftmut.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="40" y="34" width="120" height="76" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <g fill="#E8B84D" stroke="#633806" stroke-width="0.8"><ellipse cx="66" cy="58" rx="8" ry="5"/><ellipse cx="98" cy="72" rx="8" ry="5"/><ellipse cx="128" cy="56" rx="8" ry="5"/><ellipse cx="86" cy="92" rx="8" ry="5"/><ellipse cx="132" cy="90" rx="8" ry="5"/></g>
  <ellipse cx="192" cy="40" rx="9" ry="6" fill="#E8B84D" stroke="#633806" stroke-width="0.8"/>
  <g stroke="#B32D2D" stroke-width="1.5" fill="none"><path d="M180 34 q4 -6 10 -4"/><path d="M198 30 q6 2 6 8"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">ruhig bleiben beim Öffnen (Wetter beachten)</text></g>
</svg>
```

`zucht_wabensitz.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="66" y="24" width="108" height="86" rx="4" fill="none" stroke="#633806" stroke-width="3"/>
  <g fill="#E8B84D" stroke="#633806" stroke-width="0.8"><ellipse cx="92" cy="48" rx="8" ry="5"/><ellipse cx="120" cy="46" rx="8" ry="5"/><ellipse cx="148" cy="50" rx="8" ry="5"/><ellipse cx="100" cy="70" rx="8" ry="5"/><ellipse cx="132" cy="72" rx="8" ry="5"/><ellipse cx="116" cy="92" rx="8" ry="5"/></g>
  <g fill="#E8B84D" stroke="#633806" stroke-width="0.8" opacity="0.7"><ellipse cx="150" cy="122" rx="8" ry="5"/><ellipse cx="168" cy="132" rx="8" ry="5"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="152">fest sitzen (gut) vs. abtropfen</text></g>
</svg>
```

`zucht_schwarmtraegheit.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="60" y="22" width="120" height="74" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <path d="M96 96 q6 24 -6 32 q-12 -8 -6 -32 z" fill="#8a6a34" stroke="#633806" stroke-width="1.5"/>
  <path d="M132 96 q6 22 -5 30 q-11 -8 -6 -30 z" fill="#8a6a34" stroke="#633806" stroke-width="1.5"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="150">Weiselzellen am Rand = Schwarmtrieb</text></g>
</svg>
```

`zucht_volksstaerke.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="30" y="40" width="80" height="70" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <g fill="#E8B84D"><circle cx="46" cy="56" r="3"/><circle cx="60" cy="52" r="3"/><circle cx="74" cy="58" r="3"/><circle cx="90" cy="54" r="3"/><circle cx="52" cy="70" r="3"/><circle cx="68" cy="72" r="3"/><circle cx="84" cy="70" r="3"/><circle cx="58" cy="86" r="3"/><circle cx="76" cy="88" r="3"/><circle cx="92" cy="84" r="3"/><circle cx="44" cy="98" r="3"/><circle cx="66" cy="98" r="3"/><circle cx="88" cy="98" r="3"/></g>
  <rect x="130" y="40" width="80" height="70" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <g fill="#E8B84D"><circle cx="152" cy="64" r="3"/><circle cx="176" cy="72" r="3"/><circle cx="166" cy="90" r="3"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="70" y="130">stark</text><text x="170" y="130">schwach</text></g>
</svg>
```

`zucht_gesundheit.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="40" y="26" width="110" height="84" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="1.5"/>
  <g fill="#E8B84D" stroke="#c99433" stroke-width="1"><ellipse cx="64" cy="48" rx="10" ry="7"/><ellipse cx="92" cy="48" rx="10" ry="7"/><ellipse cx="120" cy="48" rx="10" ry="7"/><ellipse cx="64" cy="70" rx="10" ry="7"/><ellipse cx="120" cy="70" rx="10" ry="7"/><ellipse cx="92" cy="92" rx="10" ry="7"/></g>
  <ellipse cx="92" cy="70" rx="10" ry="7" fill="#8a6a34"/>
  <ellipse cx="92" cy="70" rx="6" ry="4" fill="#E8B84D" stroke="#633806" stroke-width="0.8"/>
  <circle cx="182" cy="54" r="22" fill="#EAF3DE" stroke="#3B6D11" stroke-width="2"/>
  <path d="M172 54 l7 8 l14 -16" fill="none" stroke="#3B6D11" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">Varroatoleranz + Bruthygiene</text></g>
</svg>
```

## 5. Tests
- `wissen_katalog_test.dart` bleibt grün (5 neue Skizzen + rechercheAssets 26/12/13; `zucht_schwarmtraegheit→weiselzelle`, `zucht_wabensitz→koenigin_finden` lösen auf).
- `bewertung_wissen_test.dart` (neu): jeder Wert in `kBewertungAchseWissen` löst via `wissenVon` auf; jeder Schlüssel ∈ `kBewertungsAchsen.map((a)=>a.key)` (aus `bewertung.dart`) — sichert Andock gegen Achsen-Umbenennung.
- `belegteKategorien` = durchsicht, varroa, krankheit, fuetterung, zucht (5 Kacheln).

## 6. Deploy
Version `1.25.0+46`, `flutter analyze`+`flutter test` grün → `bash deploy.sh`. Kein Migrations-Schritt.
