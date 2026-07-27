import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/recherche/domain/recherche_foto.dart';

/// Eigene Fotos zu den Recherche-Dokumenten (Muster: WissenFotoRepository).
class RechercheFotoRepository {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'recherche-photos');
  RechercheFotoRepository(this._c);

  /// PFLICHT-Filter auf den aktiven Betrieb: `recherche_key` ist betriebs-
  /// übergreifend gleich, und RLS erlaubt alle Betriebe des Nutzers
  /// (`meine_betrieb_ids` — Plural). Ohne diesen Filter mischten sich bei
  /// mehreren Betrieben die Fotos.
  Future<List<RechercheFoto>> ladeFotos({
    required String rechercheKey,
    required String betriebId,
  }) async {
    final res = await _c
        .from('recherche_fotos')
        .select()
        .eq('recherche_key', rechercheKey)
        .eq('betrieb_id', betriebId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((j) => RechercheFoto.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<String> signierteUrl(String storagePath) =>
      _fotos.signedUrl(storagePath);

  Future<RechercheFoto> ergaenzeFoto({
    required String rechercheKey,
    required String betriebId,
    required Uint8List jpegBytes,
    String? anker,
    String? beschriftung,
  }) async {
    final pfad = await _fotos.hochladen(
      betriebId: betriebId,
      gruppeId: rechercheKey,
      bytes: jpegBytes,
    );
    final row = await _c.from('recherche_fotos').insert({
      'recherche_key': rechercheKey,
      'storage_path': pfad,
      if (anker != null && anker.trim().isNotEmpty) 'anker': anker.trim(),
      if (beschriftung != null && beschriftung.trim().isNotEmpty)
        'beschriftung': beschriftung.trim(),
    }).select().single();
    return RechercheFoto.fromJson(row);
  }

  Future<void> loescheFoto(RechercheFoto foto) async {
    await _c.from('recherche_fotos').delete().eq('id', foto.id);
    await _fotos.entfernen([foto.storagePath]);
  }
}
