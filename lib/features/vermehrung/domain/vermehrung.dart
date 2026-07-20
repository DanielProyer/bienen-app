/// Vermehrungs-Methoden-Metadaten (Fachkonstante, pure). Quelle: Recherche 25 §10.
class VermehrungsMethode {
  final String key;
  final String label;
  /// Volk ist bei Erstellung brutfrei (nur schwarmartige Methoden) → OS-bei-Erstellung fachlich sinnvoll.
  final bool brutfreiBeiErstellung;
  const VermehrungsMethode({required this.key, required this.label, required this.brutfreiBeiErstellung});
}

const kVermehrungsMethoden = <String, VermehrungsMethode>{
  'kunstschwarm': VermehrungsMethode(key: 'kunstschwarm', label: 'Kunstschwarm', brutfreiBeiErstellung: true),
  'koeniginnen_kunstschwarm': VermehrungsMethode(
      key: 'koeniginnen_kunstschwarm', label: 'Königinnen-Kunstschwarm', brutfreiBeiErstellung: true),
  'brutableger': VermehrungsMethode(key: 'brutableger', label: 'Brutableger', brutfreiBeiErstellung: false),
  'flugling': VermehrungsMethode(key: 'flugling', label: 'Flugling', brutfreiBeiErstellung: false),
};
