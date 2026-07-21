# Wissensdatenbank Zyklus 4 — Kategorie Fütterung + Andock Fütterungs-Modul

**Datum:** 2026-07-20 · **Track:** App · **Baut auf:** Modul 4.21 (Zyklus 1-3). Kein DB/Migration. Fachquelle: `assets/recherche/02_Jahresablauf_Imker_Arosa_1570m.md` (Timing/Winterfutter, alpin), `18_Bio_Imkerei_Knospe_Schweiz.md` (Bio-Fütterung), `14_Bienengesundheit_Krankheiten_CH.md` (Fremdhonig/AFB). Kontext: `winterfutter.dart` (nur `auffuetterung` zählt fürs Ziel), `betriebs_einstellungen.winterfutter_ziel_kg` (Arosa 22).

Neue Kategorie `fuetterung` (8 Einträge: 3 Zweck + 5 Futterart). Andock: je EIN dynamisches ⓘ pro Feld im Fütterungs-Formular (Zweck-ChoiceChips + Futterart-Dropdown).

## 1. Katalog-Erweiterung (`wissen_katalog.dart`)
Kategorie ergänzen:
```dart
  WissensKategorie(key: 'fuetterung', titel: 'Fütterung', icon: 'droplet'),
```
(`'droplet': Icons.water_drop` ist in `wissen_overview_page.dart` `_katIcons` bereits vorhanden.)

8 Einträge anhängen (zeichengenau):
```dart
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
```

## 2. Andock-Maps (`lib/features/wissen/domain/fuetterung_wissen.dart`, neu)
```dart
/// Fütterungs-Zweck (fuetterung_form ChoiceChip) → Wissens-key.
const kFuetterungZweckWissen = <String, String>{
  'auffuetterung': 'auffuetterung',
  'reizfuetterung': 'reizfuetterung',
  'notfuetterung': 'notfuetterung',
};
/// Futterart (fuetterung_form Dropdown) → Wissens-key. sonstige → kein ⓘ.
const kFuetterungFutterartWissen = <String, String>{
  'zuckerwasser_1_1': 'zuckerwasser',
  'zuckerwasser_3_2': 'zuckerwasser',
  'invertsirup': 'invertsirup',
  'futterteig': 'futterteig',
  'futterwaben': 'futterwaben',
  'honig': 'honig_fuettern',
};
```

## 3. Andock im Fütterungs-Formular
`lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart` (Zweck via ChoiceChip ~Zeile 114, Futterart via Dropdown ~Zeile 120):
- neben den Zweck-ChoiceChips: `WissenInfoButton(wissenKey: kFuetterungZweckWissen[_zweck] ?? '')`.
- neben dem Futterart-Dropdown: `WissenInfoButton(wissenKey: kFuetterungFutterartWissen[_futterart] ?? '')`.
Imports `fuetterung_wissen.dart` + `wissen_info_button.dart`. Datei zuerst lesen, ⓘ minimal-invasiv (Row/Expanded) einfügen; Formularlogik (Honigreinheit-Hinweis, Bio-Flag, Mengen) unverändert.

## 4. SVG-Skizzen (`assets/wissen/`, viewBox 0 0 240 160, Stil wie bisher; Sirup blau #3d8ac0, Honig #E8B84D)

`auffuetterung.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="60" y="60" width="120" height="64" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <rect x="92" y="26" width="56" height="34" rx="3" fill="#E8EDF2" stroke="#633806" stroke-width="2"/>
  <rect x="98" y="34" width="44" height="20" rx="2" fill="#3d8ac0" opacity="0.7"/>
  <g stroke="#633806" stroke-width="2"><line x1="120" y1="60" x2="120" y2="74"/></g>
  <rect x="70" y="98" width="100" height="18" rx="2" fill="#E8B84D" stroke="#633806" stroke-width="1"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="144">dickes Futter → Wintervorrat (~20 kg)</text></g>
</svg>
```

`reizfuetterung.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <circle cx="120" cy="74" r="30" fill="#F0C24A" stroke="#633806" stroke-width="2"/>
  <circle cx="120" cy="74" r="16" fill="#E8A33D"/>
  <g fill="#3d8ac0"><circle cx="86" cy="44" r="4"/><circle cx="150" cy="46" r="4"/><circle cx="72" cy="80" r="4"/></g>
  <g stroke="#3B6D11" stroke-width="2" fill="none"><path d="M150 74 h22" marker-end="url(#rz)"/></g>
  <defs><marker id="rz" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0 0 L6 3 L0 6 z" fill="#3B6D11"/></marker></defs>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">wenig dünnes Futter → Brut anregen</text></g>
</svg>
```

`notfuetterung.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="70" y="52" width="100" height="58" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <g stroke="#B32D2D" stroke-width="3" stroke-linecap="round" fill="none"><path d="M120 44 v-20" marker-end="url(#nf)"/></g>
  <defs><marker id="nf" markerWidth="9" markerHeight="9" refX="4" refY="7" orient="auto"><path d="M4 0 L8 8 L0 8 z" fill="#B32D2D"/></marker></defs>
  <text x="120" y="86" text-anchor="middle" font-size="26" fill="#B32D2D">!</text>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="134">Beute leicht = Hunger → sofort füttern</text></g>
</svg>
```

`zuckerwasser.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <path d="M46 40 h44 l-6 66 a4 4 0 0 1 -4 4 h-20 a4 4 0 0 1 -4 -4 z" fill="#EAF2F8" stroke="#633806" stroke-width="2"/>
  <path d="M50 78 h36 l-4 28 a4 4 0 0 1 -4 4 h-20 a4 4 0 0 1 -4 -4 z" fill="#9fcbe6"/>
  <path d="M150 40 h44 l-6 66 a4 4 0 0 1 -4 4 h-20 a4 4 0 0 1 -4 -4 z" fill="#EAF2F8" stroke="#633806" stroke-width="2"/>
  <path d="M152 54 h40 l-5 52 a4 4 0 0 1 -4 4 h-22 a4 4 0 0 1 -4 -4 z" fill="#3d8ac0"/>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle"><text x="68" y="132">1:1 dünn</text><text x="172" y="132">3:2 dick</text></g>
</svg>
```

`invertsirup.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="86" y="34" width="68" height="86" rx="8" fill="#E8B84D" stroke="#633806" stroke-width="2"/>
  <rect x="104" y="22" width="32" height="16" rx="3" fill="#c99433" stroke="#633806" stroke-width="1.5"/>
  <rect x="98" y="60" width="44" height="34" rx="2" fill="#FBF6E9" stroke="#c99433" stroke-width="1"/>
  <text x="120" y="83" text-anchor="middle" font-size="12" fill="#633806">Apiinvert</text>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="140">fertig invertiert · kein Ansetzen</text></g>
</svg>
```

`futterteig.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="2" fill="none"><line x1="60" y1="70" x2="60" y2="120"/><line x1="90" y1="70" x2="90" y2="120"/><line x1="150" y1="70" x2="150" y2="120"/><line x1="180" y1="70" x2="180" y2="120"/></g>
  <rect x="78" y="44" width="84" height="30" rx="4" fill="#FBF0D6" stroke="#633806" stroke-width="2"/>
  <g fill="#e7dcc0"><circle cx="94" cy="59" r="3"/><circle cx="120" cy="55" r="3"/><circle cx="146" cy="61" r="3"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="140">fester Teig oben auf · für Kälte</text></g>
</svg>
```

`futterwaben.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="66" y="22" width="108" height="98" rx="4" fill="none" stroke="#633806" stroke-width="3"/>
  <g fill="#E8B84D" stroke="#c99433" stroke-width="1">
    <ellipse cx="92" cy="46" rx="10" ry="7"/><ellipse cx="120" cy="46" rx="10" ry="7"/><ellipse cx="148" cy="46" rx="10" ry="7"/>
    <ellipse cx="92" cy="66" rx="10" ry="7"/><ellipse cx="120" cy="66" rx="10" ry="7"/><ellipse cx="148" cy="66" rx="10" ry="7"/>
    <ellipse cx="92" cy="86" rx="10" ry="7"/><ellipse cx="120" cy="86" rx="10" ry="7"/><ellipse cx="148" cy="86" rx="10" ry="7"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="140">verdeckelte Futterwabe · natürlich</text></g>
</svg>
```

`honig_fuettern.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <path d="M84 44 h44 v66 a6 6 0 0 1 -6 6 h-32 a6 6 0 0 1 -6 -6 z" fill="#E8B84D" stroke="#633806" stroke-width="2"/>
  <rect x="80" y="34" width="52" height="12" rx="2" fill="#c99433" stroke="#633806" stroke-width="1.5"/>
  <circle cx="170" cy="60" r="22" fill="none" stroke="#B32D2D" stroke-width="3"/>
  <line x1="155" y1="75" x2="185" y2="45" stroke="#B32D2D" stroke-width="3"/>
  <text x="170" y="65" text-anchor="middle" font-size="13" fill="#8a3b1a">fremd</text>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="140">nur EIGENER Honig · Fremdhonig = AFB-Risiko</text></g>
</svg>
```

## 5. Tests
- `wissen_katalog_test.dart` bleibt grün (neue Skizzen + rechercheAssets 02/18/14; `futterwaben`/`honig_fuettern` verlinken auf bestehenden `afb`-Eintrag → verwandte lösen auf).
- `fuetterung_wissen_test.dart` (neu): jeder Wert in `kFuetterungZweckWissen` + `kFuetterungFutterartWissen` löst via `wissenVon` auf; jeder Zweck-Schlüssel ∈ `Zweck.werte`, jeder Futterart-Schlüssel ∈ `Futterart.werte` (aus `futterart.dart`).
- `belegteKategorien` = durchsicht, varroa, krankheit, fuetterung (4 Kacheln).

## 6. Deploy
Version `1.24.0+45`, `flutter analyze`+`flutter test` grün → `bash deploy.sh`. Kein Migrations-Schritt.
