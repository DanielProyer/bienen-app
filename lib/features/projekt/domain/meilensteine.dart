/// Projekt-Meilensteine (Mandant-1-Aufbau-Doku, statisch — gepflegt beim
/// Arbeitsschluss; bewusste Ausnahme von der No-Hardcode-Regel, siehe Spec §3).
enum MeilensteinStatus { erledigt, naechster, offen }

class Meilenstein {
  final String titel;
  final String wann;
  final MeilensteinStatus status;
  const Meilenstein(this.titel, this.wann, this.status);
}

const kProjektMeilensteine = <Meilenstein>[
  Meilenstein('Planung & Recherche', '2025/26', MeilensteinStatus.erledigt),
  Meilenstein('Bienenstand gebaut', 'Jul 26', MeilensteinStatus.erledigt),
  Meilenstein('Erstausstattung gekauft', 'Jul 26', MeilensteinStatus.erledigt),
  Meilenstein('Volk 1 übernommen', '19.07.26', MeilensteinStatus.erledigt),
  Meilenstein('HiveWatch-Waage live', '~Aug 26', MeilensteinStatus.naechster),
  Meilenstein('Einwinterung Volk 1', 'Herbst 26', MeilensteinStatus.offen),
  Meilenstein('Volk 2 · 1. Honigernte', '2027', MeilensteinStatus.offen),
  Meilenstein('4 Völker → max 8', '2028–30', MeilensteinStatus.offen),
];

/// Status-Zeile für die Projekt-Kopfkarte.
const kBetriebLaeuftSeit = 'Betrieb läuft seit 19.07.2026';
