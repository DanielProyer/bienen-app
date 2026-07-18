import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';

class SupabaseGesundheitGateway implements GesundheitGateway {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'health-photos');
  SupabaseGesundheitGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw GesundheitFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('gesundheitsereignisse')
          .select()
          .eq('volk_id', volkId)
          .order('festgestellt_am', ascending: false);
      return (res as List).map((j) => Gesundheitsereignis.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichern(Gesundheitsereignis e) async {
    try {
      final json = e.toInsertJson();
      if (e.id.isEmpty) {
        await _c.from('gesundheitsereignisse').insert(json);
      } else {
        await _c.from('gesundheitsereignisse').update(json).eq('id', e.id);
      }
    } catch (err) {
      _rethrow(err);
    }
  }

  @override
  Future<void> stornieren(String id, String grund) async {
    try {
      await _c.from('gesundheitsereignisse').update({
        'is_storniert': true,
        'storno_grund': grund,
        'storno_am': DateTime.now().toIso8601String().substring(0, 10),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) =>
      _fotos.hochladen(betriebId: betriebId, gruppeId: gruppeId, bytes: bytes);

  @override
  Future<String> fotoSignedUrl(String pfad) => _fotos.signedUrl(pfad);

  @override
  Future<void> fotoEntfernen(List<String> pfade) async {
    try {
      await _fotos.entfernen(pfade);
    } catch (_) {
      // best-effort
    }
  }
}
