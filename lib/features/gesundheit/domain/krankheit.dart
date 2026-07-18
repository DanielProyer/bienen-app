enum Rechtskategorie { zuBekaempfen, zuUeberwachen, nichtMeldepflichtig, neobiotaMeldung }

enum Stadium { offeneBrut, verdeckelteBrut, adulteBienen, wabenLager, mehrere }

class Krankheit {
  final String key;
  final String label;
  final Rechtskategorie rechtskategorie;
  final Stadium stadium;
  final String leitsymptome;
  final String sofortmassnahme;
  final String? meldehinweis;
  const Krankheit(this.key, this.label, this.rechtskategorie, this.stadium, this.leitsymptome,
      this.sofortmassnahme, [this.meldehinweis]);
}

/// Kanton-neutraler Melde-Text (kein GR-Hardcode, M1). Der konkrete Inspektor-Kontakt kommt via 4.23/F4.
const _meldeInspektor =
    'Meldepflichtig schon bei Verdacht: zuständigen kantonalen Bieneninspektor / kant. Veterinärdienst '
    'kontaktieren. Fachliche Begleitung: BGD 0800 274 274 (ersetzt die amtliche Meldung nicht).';

const kKrankheiten = <Krankheit>[
  Krankheit('afb', 'Amerikanische Faulbrut', Rechtskategorie.zuBekaempfen, Stadium.verdeckelteBrut,
      'Eingesunkene/durchlöcherte, feuchte Zelldeckel; braune fadenziehende Masse (Streichholzprobe); modriger Geruch.',
      'Volk geschlossen halten, NICHTS umhängen, keine Eigen-Probe einsenden — der Inspektor nimmt amtlich Probe.',
      _meldeInspektor),
  Krankheit('efb', 'Europäische Sauerbrut', Rechtskategorie.zuBekaempfen, Stadium.offeneBrut,
      'Verkrümmte, vergilbte, verrutschte offene Larven; säuerlicher Geruch; lückiges Brutbild.',
      'Volk geschlossen halten, keine Eigen-Probe — Inspektor melden.', _meldeInspektor),
  Krankheit('kleiner_beutenkaefer', 'Kleiner Beutenkäfer (Aethina tumida)', Rechtskategorie.zuBekaempfen, Stadium.mehrere,
      'Kleine dunkle Käfer/Larven im Volk, schleimig gärende Waben. CH bislang frei (APINELLA-Monitoring).',
      'Verdacht sofort melden; Käfer/Probe sichern.', _meldeInspektor),
  Krankheit('tropilaelaps', 'Tropilaelaps-Milben', Rechtskategorie.zuBekaempfen, Stadium.verdeckelteBrut,
      'Kleine, schnell laufende Milben in der Brut; geschädigte Brut. CH bislang frei.',
      'Verdacht sofort melden.', _meldeInspektor),
  Krankheit('varroa', 'Varroose', Rechtskategorie.zuUeberwachen, Stadium.mehrere,
      'Milben auf Bienen/Brut, verkrüppelte Flügel (DWV), Gemüll-Milbenfall. Flächendeckend.',
      'Kein Einzelfall-Melden. Monitoring + Behandlung — siehe Behandlungen.', null),
  Krankheit('kalkbrut', 'Kalkbrut', Rechtskategorie.nichtMeldepflichtig, Stadium.verdeckelteBrut,
      'Mumifizierte, kreideweiße/graue harte Larven; „Klappern" am Bodenbrett.',
      'Volk stärken, junge Königin, Wabenerneuerung, trockener/warmer Stand.', null),
  Krankheit('steinbrut', 'Steinbrut (Aspergillus)', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Harte, grün-gelblich verpilzte Larven. Selten; Aspergillus ist humanpathogen (Atemwege).',
      'ARBEITSSCHUTZ: Handschuhe + FFP2/FFP3-Maske, Sporen nicht einatmen, befallene Waben entsorgen.', null),
  Krankheit('sackbrut', 'Sackbrut', Rechtskategorie.nichtMeldepflichtig, Stadium.verdeckelteBrut,
      'Gestreckte, sackförmige (flüssigkeitsgefüllte) Larven, hochgezogene Köpfchen. AFB-VERWECHSLUNGSGEFAHR.',
      'Streichholz-/Fadenzugprobe machen; bei Unsicherheit wie AFB behandeln = melden. Volk stärken.', null),
  Krankheit('nosema', 'Nosemose', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Durchfall/Ruhr, geschwächte Völker, Kotspritzer; Nachweis nur mikroskopisch.',
      'Hygiene, Wabenerneuerung, starke Völker; ggf. Probe an Agroscope/BGD.', null),
  Krankheit('ruhr', 'Ruhr / Durchfall', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Kotspritzer an Beute/Waben; oft Folge schlechten Winterfutters oder Nosema.',
      'Futterqualität prüfen, Reinigungsflug abwarten, Nosema abklären.', null),
  Krankheit('viren', 'Viruserkrankungen (DWV/ABPV/CBPV)', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Verkrüppelte Flügel (DWV, varroagekoppelt), zitternde/haarlose schwarze Bienen (CBPV).',
      'Varroa senken (Hauptursache DWV), Volk stärken, junge Königin.', null),
  Krankheit('wachsmotte', 'Wachsmotte', Rechtskategorie.nichtMeldepflichtig, Stadium.wabenLager,
      'Gespinste/Fraßgänge in Waben (v. a. Lager & schwache Völker).',
      'Nur starke Völker; Waben kühl/luftig lagern; Lagerhygiene.', null),
  Krankheit('braula', 'Bienenlaus (Braula coeca)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Kleine flügellose „Läuse" auf Bienen/Königin. Harmlos; nicht mit Varroa verwechseln.',
      'Keine spezifische Behandlung nötig.', null),
  Krankheit('tracheenmilbe', 'Tracheenmilbe (Acarapis woodi)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Krabbelnde, flugunfähige Bienen; Nachweis nur mikroskopisch. In CH nachrangig.',
      'Meist keine spezifische Behandlung; die Ameisensäure gegen Varroa wirkt mit.', null),
  Krankheit('vergiftung', 'Vergiftung (Pflanzenschutzmittel)', Rechtskategorie.nichtMeldepflichtig, Stadium.adulteBienen,
      'Schlagartiges Massensterben vor der Beute bei GESUNDER Brut; volle Kröpfe/Pollen.',
      'SOFORT Proben (tote Bienen + verdächtige Pflanze/Feld) VOR Regen ziehen — kurzes Nachweisfenster.',
      'Verdacht Bienenvergiftung → BGD 0800 274 274 / Agroscope informieren (NICHT primär der Inspektor); '
      'ggf. kantonale Stelle. Nachweis-/versicherungsrelevant.'),
  Krankheit('vespa_velutina', 'Asiatische Hornisse (Vespa velutina)', Rechtskategorie.neobiotaMeldung, Stadium.adulteBienen,
      'Vor dem Flugloch rüttelnd jagende dunkle Hornissen; Nest hoch in Bäumen.',
      'Nester NICHT selbst entfernen (Spezialisten). Fund mit Foto + Standort melden.',
      'Fund (Tier oder Nest) über asiatischehornisse.ch melden (geht an infofauna/Agroscope + kantonale Kontaktperson).'),
  Krankheit('sonstige', 'Sonstige / unklar', Rechtskategorie.nichtMeldepflichtig, Stadium.mehrere,
      'Unklarer Befund.', 'Beobachten, dokumentieren; im Zweifel BGD 0800 274 274 fragen.', null),
];

Krankheit? katalogEintrag(String key) {
  for (final k in kKrankheiten) {
    if (k.key == key) return k;
  }
  return null;
}

Rechtskategorie? rechtskategorieVon(String key) => katalogEintrag(key)?.rechtskategorie;

/// Löst einen Melde-Hinweis aus (rote Banner-/Neobiota-Meldung).
bool istMeldepflichtig(String key) {
  final r = rechtskategorieVon(key);
  return r == Rechtskategorie.zuBekaempfen || r == Rechtskategorie.neobiotaMeldung;
}

/// Single-Source der Katalog-Keys (für den DB-CHECK-Paritätstest, M3).
final Set<String> krankheitKeys = kKrankheiten.map((k) => k.key).toSet();

/// 4.3-Durchsichts-Flag → Krankheit-Key (null = keine Krankheit).
String? durchsichtFlagZuKrankheit(String flag) => switch (flag) {
      'faulbrut_verdacht' => 'afb',
      'sauerbrut_verdacht' => 'efb',
      'kalkbrut' => 'kalkbrut',
      'sackbrut' => 'sackbrut',
      'varroa_sichtbar' => 'varroa',
      'ruhr' => 'ruhr',
      'wachsmotte' => 'wachsmotte',
      _ => null,
    };
