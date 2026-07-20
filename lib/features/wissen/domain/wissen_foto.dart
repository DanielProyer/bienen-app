/// Read-only: Rows werden nur gelesen; Schreiben läuft über das Repository (Upload). Kein toJson.
class WissenFoto {
  final String id;
  final String wissenKey;
  final String storagePath;
  final String? beschriftung;
  final DateTime createdAt;
  const WissenFoto({
    required this.id, required this.wissenKey, required this.storagePath,
    this.beschriftung, required this.createdAt,
  });
  factory WissenFoto.fromJson(Map<String, dynamic> j) => WissenFoto(
        id: j['id'] as String,
        wissenKey: j['wissen_key'] as String,
        storagePath: j['storage_path'] as String,
        beschriftung: j['beschriftung'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
