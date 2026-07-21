/// Ein weiterführender Link eines Wissens-Eintrags — GENAU eine Quelle.
class WissensLink {
  final String label;
  final String? rechercheAsset; // z.B. 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'
  final String? url;            // externe Quelle (z.B. BGD-Merkblatt)
  const WissensLink({required this.label, this.rechercheAsset, this.url})
      : assert((rechercheAsset == null) != (url == null),
            'Genau eine Quelle: rechercheAsset ODER url');
}

/// Attribution eines kuratierten Fotos. CC-BY → Zeile sichtbar; CC0/PD → optional, aber wir zeigen sie einheitlich.
class WissensBildquelle {
  final String autor;   // '' bei anonym
  final String lizenz;  // 'CC BY 3.0' | 'CC BY 2.0' | 'CC0' | 'Public Domain' | 'CC0 / Public Domain' | 'CC BY 3.0 US'
  final String url;     // Commons File-Seite
  const WissensBildquelle({required this.autor, required this.lizenz, required this.url});
  String get zeile => autor.isEmpty ? 'Foto · $lizenz' : 'Foto: $autor · $lizenz';
}

/// Ein Wissens-Eintrag = eine „schnelle Info" mit Skizze + Weiterführung.
class WissensEintrag {
  final String key;            // STABIL — der Deep-Link-Anker, eindeutig
  final String titel;
  final String kurzinfo;
  final String kategorie;      // WissensKategorie.key
  final String? skizze;        // Asset-Pfad SVG
  final String? foto;          // Asset unter assets/wissen/fotos/
  final WissensBildquelle? fotoQuelle;
  final List<WissensLink> mehr;
  final List<String> verwandte;
  final List<String> stichworte;
  const WissensEintrag({
    required this.key, required this.titel, required this.kurzinfo, required this.kategorie,
    this.skizze, this.foto, this.fotoQuelle,
    this.mehr = const [], this.verwandte = const [], this.stichworte = const [],
  }) : assert(foto == null || fotoQuelle != null, 'Foto braucht eine Attribution');
}

/// Kategorie = ein Schritt im Imkerei-Prozess (Übersicht-Kacheln).
class WissensKategorie {
  final String key;
  final String titel;
  final String icon; // Icon-Name-Mapping in der UI
  const WissensKategorie({required this.key, required this.titel, required this.icon});
}
