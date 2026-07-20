import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

class WissenFotoRepository {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'wissen-photos');
  WissenFotoRepository(this._c);

  /// PFLICHT-Filter auf den aktiven Betrieb: wissen_key ist betriebsübergreifend gleich,
  /// RLS (meine_betrieb_ids = Plural) allein würde Mehrbetriebs-Fotos mischen.
  Future<List<WissenFoto>> ladeFotos({required String wissenKey, required String betriebId}) async {
    final res = await _c
        .from('wissen_fotos')
        .select()
        .eq('wissen_key', wissenKey)
        .eq('betrieb_id', betriebId)
        .order('created_at', ascending: false);
    return (res as List).map((j) => WissenFoto.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<String> signierteUrl(String storagePath) => _fotos.signedUrl(storagePath);

  Future<WissenFoto> ergaenzeFoto({
    required String wissenKey,
    required String betriebId,
    required Uint8List jpegBytes,
    String? beschriftung,
  }) async {
    final pfad = await _fotos.hochladen(betriebId: betriebId, gruppeId: wissenKey, bytes: jpegBytes);
    final row = await _c.from('wissen_fotos').insert({
      'wissen_key': wissenKey,
      'storage_path': pfad,
      if (beschriftung != null && beschriftung.trim().isNotEmpty) 'beschriftung': beschriftung.trim(),
    }).select().single();
    return WissenFoto.fromJson(row);
  }

  Future<void> loescheFoto(WissenFoto foto) async {
    await _c.from('wissen_fotos').delete().eq('id', foto.id);
    await _fotos.entfernen([foto.storagePath]);
  }
}
