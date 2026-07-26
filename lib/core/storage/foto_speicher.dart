import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/ohne_metadaten.dart';

/// Storage-Helfer fuer PRIVATE Buckets: laedt hoch (gibt den PFAD zurueck,
/// nicht die URL), erzeugt Signed-URLs, entfernt Objekte.
/// Pfadkonvention: `<betrieb_id>[/<gruppe>]/<datei>` (mandanten-scoped fuer die
/// Storage-Policies).
///
/// **Einziger Upload-Weg der App.** Der Metadaten-Strip laeuft hier, damit ihn
/// kein Aufrufer vergessen kann (eine Stelle statt sechs).
class FotoSpeicher {
  final SupabaseClient _c;
  final String bucket;

  /// Nur fuer Tests injizierbar; Produktion nutzt [ohneMetadaten].
  final Future<Uint8List> Function(Uint8List)? strip;

  const FotoSpeicher(this._c, this.bucket, {this.strip});

  /// [gruppeId] optional (Zwischenebene, z. B. volk_id/material_id).
  /// [dateiname] optional: gesetzt = deterministischer Pfad (ersetzt das
  /// bestehende Objekt via upsert, z. B. `<stepKey>.jpg` pro Bauschritt);
  /// weggelassen = `foto_<microsec>.jpg`.
  ///
  /// Wirft, wenn die Bytes nicht als Bild verarbeitbar sind (z. B. HEIC) —
  /// bewusst, statt ein Original mit GPS hochzuladen.
  Future<String> hochladen({
    required String betriebId,
    required Uint8List bytes,
    String? gruppeId,
    String? dateiname,
  }) async {
    final sauber = await (strip ?? ohneMetadaten)(bytes);
    final datei =
        dateiname ?? 'foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final pfad = [betriebId, ?gruppeId, datei].join('/');
    await _c.storage.from(bucket).uploadBinary(
          pfad,
          sauber,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
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
