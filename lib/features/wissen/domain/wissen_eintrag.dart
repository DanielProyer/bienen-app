/// Ein weiterführender Link eines Wissens-Eintrags — GENAU eine Quelle.
class WissensLink {
  final String label;
  final String? rechercheAsset; // z.B. 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'
  final String? url;            // externe Quelle (z.B. BGD-Merkblatt)
  const WissensLink({required this.label, this.rechercheAsset, this.url})
      : assert((rechercheAsset == null) != (url == null),
            'Genau eine Quelle: rechercheAsset ODER url');
}

/// Ein Wissens-Eintrag = eine „schnelle Info" mit Skizze + Weiterführung.
class WissensEintrag {
  final String key;            // STABIL — der Deep-Link-Anker, eindeutig
  final String titel;
  final String kurzinfo;
  final String kategorie;      // WissensKategorie.key
  final String? skizze;        // Asset-Pfad SVG
  final List<WissensLink> mehr;
  final List<String> verwandte;
  final List<String> stichworte;
  const WissensEintrag({
    required this.key, required this.titel, required this.kurzinfo, required this.kategorie,
    this.skizze, this.mehr = const [], this.verwandte = const [], this.stichworte = const [],
  });
}

/// Kategorie = ein Schritt im Imkerei-Prozess (Übersicht-Kacheln).
class WissensKategorie {
  final String key;
  final String titel;
  final String icon; // Icon-Name-Mapping in der UI
  const WissensKategorie({required this.key, required this.titel, required this.icon});
}
