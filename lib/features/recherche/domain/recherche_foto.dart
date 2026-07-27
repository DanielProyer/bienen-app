/// Ein eigenes Foto zu einer Recherche, optional an ein Kapitel gehängt.
///
/// Read-only: Zeilen werden nur gelesen, geschrieben wird über das Repository
/// (Upload + Insert in einem Zug). Deshalb kein `toJson`.
///
/// `anker` ist die Sprungmarke des Kapitels (siehe `markdown_anker.dart`).
/// Ist er null, gehört das Foto zum Dokument als Ganzes und erscheint am Ende.
class RechercheFoto {
  final String id;
  final String rechercheKey;
  final String? anker;
  final String storagePath;
  final String? beschriftung;
  final DateTime createdAt;

  const RechercheFoto({
    required this.id,
    required this.rechercheKey,
    required this.anker,
    required this.storagePath,
    this.beschriftung,
    required this.createdAt,
  });

  factory RechercheFoto.fromJson(Map<String, dynamic> j) => RechercheFoto(
        id: j['id'] as String,
        rechercheKey: j['recherche_key'] as String,
        anker: j['anker'] as String?,
        storagePath: j['storage_path'] as String,
        beschriftung: j['beschriftung'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Der Dokumentschlüssel zu einem Asset-Pfad: Dateiname ohne Ordner und Endung.
///
/// `assets/recherche/30_Varroa_Bildzaehlung_Automatisierung.md`
/// → `30_Varroa_Bildzaehlung_Automatisierung`
///
/// Bewusst aus dem Dateinamen abgeleitet statt aus einer zweiten Liste: Eine
/// separate Zuordnung müsste bei jedem neuen Dokument gepflegt werden und liefe
/// sonst still auseinander.
String rechercheKeyAusAssetPfad(String assetPfad) {
  final datei = assetPfad.split('/').last;
  return datei.endsWith('.md')
      ? datei.substring(0, datei.length - 3)
      : datei;
}
