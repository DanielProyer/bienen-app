/// Statische, verbindliche Bau-Inhalte (aus Bauplan v4 abgeleitet).
/// Nur der Fortschritt (abgehakt/Notiz/Foto) liegt in Supabase – dieser
/// Inhalt ist fest im App-Code und wird per [key] mit dem Fortschritt verbunden.
class BuildStepContent {
  final String key;
  final String title;
  final List<String> instructions;
  final String? soll;
  final String? tip;
  final List<String> drawings; // Asset-Pfade

  const BuildStepContent({
    required this.key,
    required this.title,
    this.instructions = const [],
    this.soll,
    this.tip,
    this.drawings = const [],
  });
}

/// Die 12 Bauschritte in Reihenfolge.
const kBuildSteps = <BuildStepContent>[
  BuildStepContent(
    key: 'doppelbalken',
    title: 'Doppelbalken bauen',
    instructions: [
      '4 Douglasie-Rahmenhölzer 90×90 (3 m) je auf 2,8 m ablängen – 4 durchgehende Bretter für 2 Balken (Reststück 20 cm).',
      'Je Balkenseite 2 Bretter deckungsgleich aufeinanderlegen (untere + obere Lage).',
      'Kontaktflächen vollflächig mit D4-Leim bestreichen.',
      'Beide Lagen alle ~20 cm mit 8×100-Schrauben (versetzt) verschrauben.',
      'Ergebnis: 2 durchgehende Doppelbalken à 2,8 m – ohne Stoss.',
    ],
    soll: 'Bretter gerade und bündig verleimt; keine Stösse.',
    tip: 'Durchgehende Bretter = maximale Steifigkeit. Die zwei verleimten Lagen wirken zugleich gegen Verzug – D4-Leim (wasserfest) vollflächig auftragen.',
    drawings: ['assets/bau/01_doppelbalken.png'],
  ),
  BuildStepContent(
    key: 'rechteck',
    title: 'Standort & Rechteck anzeichnen',
    instructions: [
      'Fester, sonniger, windgeschützter Platz; Fluglöcher später nach Südost, Flugbahn 2–3 m frei, hinten 80–100 cm Arbeitsraum.',
      'Rechteck 2000 × 400 mm anzeichnen: Beinabstand längs 2000 mm, Balkenachse (vorn/hinten) 400 mm.',
      'Beine ~400 mm von den Enden einrücken.',
      'Rechtwinkligkeit mit einer Latten-Lehre und gleichen Diagonalen prüfen.',
    ],
    soll: 'Beinabstand 2000 mm, Achse 400 mm, Diagonalen gleich.',
    drawings: ['assets/bau/02_draufsicht_rechteck.png'],
  ),
  BuildStepContent(
    key: 'erdschrauben',
    title: 'Erdschrauben eindrehen',
    instructions: [
      '4× Krinner U-FIX 91 an den angezeichneten Punkten ansetzen.',
      'Mit einem Stahlstab durch die Aufnahme lotrecht eindrehen.',
      'Mit der Wasserwaage an der Hülse laufend die Senkrechte kontrollieren.',
      'Die 4 Aufnahmen grob auf gleiche Höhe bringen (Feinausgleich folgt über die Bolzen).',
    ],
    soll: 'Jede Erdschraube lotrecht; Positionen = angezeichnetes Rechteck.',
    tip: 'Auf Steine/Wurzeln achten – notfalls Schraube leicht versetzen, das Rechteck aber halten.',
    drawings: ['assets/bau/03_erdschraube_lot.png'],
  ),
  BuildStepContent(
    key: 'pfosten',
    title: 'Pfosten setzen',
    instructions: [
      '4 Pfosten aus Douglasie 90×90 auf ~120 mm zuschneiden.',
      'Je Pfosten in eine U-FIX-Aufnahme stellen.',
      'Seitlich mit 8×100-Schraube durchbolzen.',
    ],
    soll: 'Pfosten fest, grob gleiche Oberkante.',
    drawings: ['assets/bau/04_pfosten_ufix.png'],
  ),
  BuildStepContent(
    key: 'nivellierbolzen',
    title: 'Nivellier-Bolzen einbauen',
    instructions: [
      'In jeden Pfostenkopf mittig 16 mm bohren (Forstner-/Holzbohrer).',
      'Einschlagmutter M16 bündig einsetzen.',
      'Sechskantschraube M16×100 eindrehen, grosse Auflagescheibe auflegen.',
      'Kontermutter aufsetzen, aber noch NICHT kontern (Feinjustage folgt beim Nivellieren).',
    ],
    soll: 'Schraube leichtgängig, Scheibe plan, Verstellweg ±25 mm frei.',
    drawings: ['assets/bau/05_nivellierbolzen.png'],
  ),
  BuildStepContent(
    key: 'nivellieren',
    title: 'Balken auflegen & nivellieren',
    instructions: [
      'Die 2 Doppelbalken auf die 4 Auflagescheiben legen (Achse 400 mm).',
      'Mit Kreuzlinienlaser oder Schlauchwaage die 4 Bolzen in EINE Ebene drehen – in Längs- UND Querrichtung waagerecht.',
      'Kontermuttern fest anziehen.',
      'Jeden Balken mit 2 Schwerlast-Winkeln (90×90×65) auf den Pfosten sichern (8 Winkel gesamt).',
    ],
    soll: 'Balken-Oberkante waagerecht längs UND quer; Kontermuttern fest.',
    tip: 'Schlüsselschritt – hier entsteht die ebene, rückenschonende Höhe. Ruhig mehrfach nachmessen.',
    drawings: [
      'assets/bau/06_querschnitt_aufbau.png',
      'assets/bau/05_nivellierbolzen.png',
    ],
  ),
  BuildStepContent(
    key: 'platten_zuschnitt',
    title: 'Platten zuschneiden & versiegeln',
    instructions: [
      '4 Platten 560 × 500 mm aus der Schaltafel zuschneiden (falls nicht im Markt geschnitten).',
      'Alle Schnittkanten SOFORT versiegeln (Hirnholz zuerst) – grösster Langlebigkeits-Faktor.',
      'Je Platte 2–4 Entwässerungslöcher Ø 8 mm bohren.',
    ],
    soll: 'Kanten rundum versiegelt; Löcher gebohrt.',
    drawings: ['assets/bau/07_platte_entwaesserung.png'],
  ),
  BuildStepContent(
    key: 'platten_montage',
    title: 'Platten aufschrauben',
    instructions: [
      'Je Platte mittig über beide Balken legen (fasst die Waage 500×430 mit Rand).',
      'Von oben mit Terrassenschraube A2 5×50 verschrauben (steift den Stand aus).',
      'Jede Platte mit der Wasserwaage prüfen.',
    ],
    soll: 'Jede Platte waagerecht (wichtig für Waagengenauigkeit); Völkerabstand ≈ 265 mm, Plattenlücke ~160 mm.',
    drawings: ['assets/bau/08_platte_auf_balken.png'],
  ),
  BuildStepContent(
    key: 'oel',
    title: 'Ölen & lasieren',
    instructions: [
      'Ganzen Stand mit Holzöl/UV-Lasur behandeln, v. a. Hirnholz und Schnittkanten.',
      'Trocknungszeit laut Hersteller einhalten.',
    ],
    soll: 'Kein blankes Hirnholz mehr; alle Flächen behandelt.',
    tip: 'Unbehandeltes Douglasie ist bienenfreundlich – nur aussen/Kanten schützen, keine Biozide an der Beute.',
    drawings: ['assets/bau/10_seitenansicht_gesamt.png'],
  ),
  BuildStepContent(
    key: 'waagen_beuten',
    title: 'Waagen & Beuten aufsetzen',
    instructions: [
      'HiveWatch-Waage je Platte LOSE auflegen – nichts seitlich überbrücken (keine Steine/Leisten).',
      '3-m-Kabel in einer Kantennut am Pfosten herabführen, Logger geschützt platzieren.',
      'Waagen tarieren.',
      'Beuten aufsetzen (Reihenfolge Platte → Waage → Beute), Flugrichtung Südost prüfen, kalibrieren.',
    ],
    soll: 'Beutenboden ≈ 44 cm; Waage frei (nichts überbrückt).',
    drawings: ['assets/bau/09_waagenstapel.png'],
  ),
  BuildStepContent(
    key: 'endabnahme',
    title: 'Endabnahme',
    instructions: [
      'Alle Balken waagerecht, Kontermuttern fest.',
      'Alle 8 Schwerlast-Winkel montiert.',
      'Alle 4 Platten waagerecht & verschraubt, Entwässerungslöcher offen.',
      'Alle Schnittkanten/Hirnholz versiegelt und behandelt.',
      'Fluglöcher Südost, Flugbahn frei, hinten 80–100 cm Arbeitsraum.',
    ],
    soll: 'Keine Durchbiegung sichtbar (< 0,5 mm bei Vollvolk).',
    drawings: ['assets/bau/10_seitenansicht_gesamt.png'],
  ),
  BuildStepContent(
    key: 'nachkontrolle',
    title: 'Nachkontrolle (nach 2–4 Wochen)',
    instructions: [
      'Nach 2–4 Wochen die Setzung prüfen.',
      'Mit den 4 Bolzen nachnivellieren (Laser/Wasserwaage).',
      'Alle Schrauben nachziehen (Winkel, Platten, Doppelbalken).',
    ],
    soll: 'Wieder exakt waagerecht; keine losen Verbindungen.',
    drawings: ['assets/bau/05_nivellierbolzen.png'],
  ),
];
