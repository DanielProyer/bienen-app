import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Duenner Storage-Helfer fuer PRIVATE Buckets: laedt hoch (gibt den PFAD zurueck,
/// nicht die URL), erzeugt Signed-URLs, entfernt Objekte. Pfadkonvention:
/// `<betrieb_id>/<gruppe>/foto_<ts>.jpg` (mandanten-scoped fuer die Storage-Policies).
class FotoSpeicher {
  final SupabaseClient _c;
  final String bucket;
  const FotoSpeicher(this._c, this.bucket);

  Future<String> hochladen({
    required String betriebId,
    required String gruppeId,
    required Uint8List bytes,
  }) async {
    final pfad = '$betriebId/$gruppeId/foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _c.storage.from(bucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return pfad;
  }

  Future<String> signedUrl(String pfad, {int ablaufSekunden = 3600}) =>
      _c.storage.from(bucket).createSignedUrl(pfad, ablaufSekunden);

  Future<void> entfernen(List<String> pfade) async {
    if (pfade.isEmpty) return;
    await _c.storage.from(bucket).remove(pfade);
  }
}
