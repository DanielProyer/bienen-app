# Wissensdatenbank Zyklus 3 — Kategorie Krankheiten + Andock Gesundheit

**Datum:** 2026-07-20 · **Track:** App · **Baut auf:** Modul 4.21 (Zyklus 1/2). Kein DB/Migration. Fachquelle: `assets/recherche/14_Bienengesundheit_Krankheiten_CH.md`, `23_Krankheiten_Schaedlinge_BGD.md`, `24_Asiatische_Hornisse_Vespa_velutina.md` **und** der bestehende Domain-Katalog `lib/features/gesundheit/domain/krankheit.dart`.

## Designentscheid — nichts doppelt bauen (D-59)
`krankheit.dart` ist bereits die **Single Source** für `leitsymptome` / `sofortmassnahme` / `meldehinweis` / Rechtskategorie (kanton-neutral, review-fest), und das Gesundheits-Formular zeigt sie inline + Meldepflicht-Banner. Die Wissensschicht **dupliziert diesen Text NICHT** und kodiert **keine** Meldepflicht autoritativ (die bleibt in `krankheit.dart` / Banner / Recherche). Sie ergänzt nur, was fehlt: **SVG-Skizze (Bild-Erkennung), expliziter Verwechslungs-Hinweis, Recherche-Deeplink, Durchstöbern in `/wissen`**. Die Kurzinfos sind bewusst **erkennungs-/verwechslungs-fokussiert** und mit `krankheit.dart` konsistent (keine widersprüchlichen Aussagen). Cross-Reuse: die Krankheiten `varroa`/`viren` docken auf den bestehenden Varroa-Eintrag `varroa_milbe` (kein neuer Eintrag).

## 1. Katalog-Erweiterung (`wissen_katalog.dart`)
Kategorie ergänzen:
```dart
  WissensKategorie(key: 'krankheit', titel: 'Krankheiten', icon: 'health'),
```
Icon-Mapping in `wissen_overview_page.dart` `_katIcons` ergänzen: `'health': Icons.healing`.

6 Einträge anhängen (zeichengenau):
```dart
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
```

### 1b. Bestehenden Varroa-Eintrag ergänzen (Fachreview minor)
Da die Krankheit-Keys `varroa`/`viren` auf `varroa_milbe` andocken, `viren` aber auch CBPV (nicht varroagekoppelt) umfasst: in `wissen_katalog.dart` im bestehenden Eintrag `varroa_milbe` die `kurzinfo` am Ende ergänzen um: „ **Hinweis:** nicht alle Bienenviren sind varroagekoppelt — die Chronische Bienenparalyse (CBPV: zitternde, haarlose schwarze Bienen) entsteht durch Stress/Dichte." (nur diesen Satz anhängen, Rest unverändert).

## 2. Andock-Map (`lib/features/wissen/domain/gesundheit_wissen.dart`, neu)
```dart
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
```

## 3. Andock im Gesundheits-Formular
`lib/features/gesundheit/presentation/pages/gesundheit_form_page.dart`: neben dem Krankheits-`DropdownButtonFormField` (`_krankheit`, ~Zeile 95) ein `WissenInfoButton(wissenKey: kKrankheitWissen[_krankheit] ?? '')` (dynamisch, aktualisiert sich via `setState`). Imports `gesundheit_wissen.dart` + `wissen_info_button.dart`. Meldepflicht-Banner + Leitsymptom-Anzeige bleiben unverändert (der ⓘ ergänzt nur Bild + Deeplink).

## 4. SVG-Skizzen (`assets/wissen/`, viewBox 0 0 240 160, Stil wie bisher)

`afb.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="1.5">
    <rect x="20" y="26" width="120" height="86" rx="4" fill="#C9A66B"/>
    <g fill="#6b4a24"><ellipse cx="46" cy="50" rx="12" ry="9"/><ellipse cx="80" cy="66" rx="12" ry="9"/><ellipse cx="112" cy="48" rx="12" ry="9"/><ellipse cx="62" cy="90" rx="12" ry="9"/><ellipse cx="108" cy="86" rx="12" ry="9"/></g>
    <g fill="#3d2a14"><circle cx="46" cy="50" r="3"/><circle cx="80" cy="66" r="3"/><circle cx="112" cy="48" r="3"/></g>
  </g>
  <line x1="168" y1="30" x2="182" y2="96" stroke="#c9a66b" stroke-width="5" stroke-linecap="round"/>
  <path d="M182 96 q6 12 2 24" stroke="#7a4a1a" stroke-width="3" fill="none" stroke-linecap="round"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">eingesunkene Deckel · Fadenzug (Streichholz)</text></g>
</svg>
```

`efb.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="1.5" fill="none">
    <rect x="40" y="24" width="160" height="88" rx="4" fill="#EBD9A8"/>
    <g stroke="#c9a66b"><line x1="80" y1="24" x2="80" y2="112"/><line x1="120" y1="24" x2="120" y2="112"/><line x1="160" y1="24" x2="160" y2="112"/><line x1="40" y1="68" x2="200" y2="68"/></g>
  </g>
  <g fill="#d9c060" stroke="#8a6a2e" stroke-width="1"><path d="M52 44 q10 -6 16 4 q-8 8 -16 2 z"/><path d="M96 90 q12 -4 14 8 q-10 6 -16 -2 z"/><path d="M132 46 q12 2 8 14 q-12 2 -12 -8 z"/><path d="M168 92 q10 -8 16 2 q-6 10 -16 4 z"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">verrutschte, verkrümmte OFFENE Larven</text></g>
</svg>
```

`kalkbrut.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="30" y="22" width="130" height="74" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="1.5"/>
  <g fill="#FBFBF7" stroke="#b8b8ae" stroke-width="1"><ellipse cx="56" cy="44" rx="11" ry="8"/><ellipse cx="90" cy="58" rx="11" ry="8"/><ellipse cx="124" cy="44" rx="11" ry="8"/><ellipse cx="78" cy="80" rx="11" ry="8"/><ellipse cx="120" cy="76" rx="11" ry="8"/></g>
  <g fill="#EDEDE6" stroke="#b8b8ae" stroke-width="1"><ellipse cx="150" cy="116" rx="10" ry="6"/><ellipse cx="176" cy="120" rx="10" ry="6"/><ellipse cx="120" cy="120" rx="10" ry="6"/></g>
  <line x1="40" y1="104" x2="210" y2="104" stroke="#633806" stroke-width="2"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="144">weiße harte Mumien · „Klappern" am Boden</text></g>
</svg>
```

`steinbrut.svg` (Warnvariante der Kalkbrut — grünliche Mumien + Masken-Warnzeichen):
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="30" y="24" width="130" height="74" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="1.5"/>
  <g fill="#c7cf8a" stroke="#7e8a4a" stroke-width="1"><ellipse cx="56" cy="46" rx="11" ry="8"/><ellipse cx="90" cy="60" rx="11" ry="8"/><ellipse cx="124" cy="46" rx="11" ry="8"/><ellipse cx="80" cy="82" rx="11" ry="8"/></g>
  <path d="M172 44 h20 v9 a10 8 0 0 1 -20 0 z" fill="#E8EDF2" stroke="#633806" stroke-width="1.5"/>
  <circle cx="182" cy="50" r="22" fill="none" stroke="#B32D2D" stroke-width="3"/>
  <line x1="167" y1="66" x2="197" y2="34" stroke="#B32D2D" stroke-width="3"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="130">grünliche Mumien · FFP-Maske (Aspergillus)</text></g>
</svg>
```

`sackbrut.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="60" y="24" width="120" height="80" rx="6" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <path d="M96 44 q40 6 44 34 q-4 12 -18 12 q-8 -34 -30 -34 q0 -8 4 -12 z" fill="#EBD9A8" stroke="#8a6a2e" stroke-width="1.5"/>
  <path d="M96 44 q10 -8 20 -4" stroke="#8a6a2e" stroke-width="2.5" fill="none" stroke-linecap="round"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="130">sackförmige Larve, Köpfchen hoch · KEIN Faden</text></g>
</svg>
```

`ruhr_nosema.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="54" y="24" width="132" height="86" rx="4" fill="#E8C98A" stroke="#633806" stroke-width="2"/>
  <rect x="88" y="96" width="64" height="14" rx="2" fill="#3d2a14"/>
  <g stroke="#6b4a24" stroke-width="3" stroke-linecap="round" fill="none"><path d="M74 44 q6 14 -2 30"/><path d="M104 40 q8 16 0 34"/><path d="M140 46 q-6 16 4 28"/><path d="M168 42 q6 14 -2 30"/></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="132">Kotspritzer an Beute &amp; Waben = Durchfall</text></g>
</svg>
```

`vespa_velutina.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="26" y="86" width="150" height="46" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="2"/>
  <rect x="60" y="120" width="82" height="12" rx="2" fill="#3d2a14"/>
  <g><ellipse cx="150" cy="52" rx="22" ry="12" fill="#3d2f26" stroke="#1c140e" stroke-width="1.5"/><path d="M150 52 h20" stroke="#E8A33D" stroke-width="4"/><circle cx="126" cy="50" r="7" fill="#D8863A"/><g stroke="#3d2f26" stroke-width="2"><line x1="140" y1="64" x2="134" y2="76"/><line x1="152" y1="64" x2="150" y2="78"/><line x1="164" y1="62" x2="170" y2="74"/></g><g stroke="#E8C43D" stroke-width="3" stroke-linecap="round"><line x1="133" y1="75" x2="130" y2="79"/><line x1="150" y1="77" x2="150" y2="81"/><line x1="169" y1="73" x2="172" y2="77"/></g></g>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle"><text x="120" y="150">jagt rüttelnd vor dem Flugloch</text></g>
</svg>
```

## 5. Tests
- `wissen_katalog_test.dart` bleibt grün (neue Skizzen + rechercheAssets 14/23/24 vorhanden; `afb↔sackbrut↔efb` etc. lösen auf).
- `gesundheit_wissen_test.dart` (neu): jeder Wert in `kKrankheitWissen` löst via `wissenVon` auf; jeder Schlüssel ∈ `krankheitKeys` (aus `krankheit.dart`) — stellt sicher, dass kein Andock auf einen entfernten Krankheit-Key zeigt.
- `belegteKategorien` enthält jetzt `durchsicht`, `varroa`, `krankheit` (3 Kacheln).

## 6. Deploy
Version `1.23.0+44`, `flutter analyze`+`flutter test` grün → `bash deploy.sh`. Kein Migrations-Schritt.
