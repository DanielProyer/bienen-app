import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';

class SupabaseFuetterungGateway implements FuetterungGateway {
  final SupabaseClient _c;
  SupabaseFuetterungGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw FuetterungFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('fuetterungen')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => Fuetterung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<int> fuetterungErfassen({
    required List<String> volkIds,
    required DateTime durchgefuehrtAm,
    required String zweck,
    required String futterart,
    required bool bioZertifiziert,
    required num mengeProVolkKg,
    String? materialId,
    String? verantwortlichePerson,
    String? notiz,
  }) async {
    try {
      final n = await _c.rpc('fuetterung_erfassen', params: {
        'p_volk_ids': volkIds,
        'p_durchgefuehrt_am': _iso(durchgefuehrtAm),
        'p_zweck': zweck,
        'p_futterart': futterart,
        'p_menge_pro_volk_kg': mengeProVolkKg,
        'p_bio_zertifiziert': bioZertifiziert,
        'p_material_id': materialId,
        'p_verantwortliche_person': verantwortlichePerson,
        'p_notiz': notiz,
      });
      return (n as num).toInt();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> fuetterungStornieren(String id, String grund) async {
    try {
      await _c.from('fuetterungen').update({
        'is_storniert': true,
        'storno_grund': grund,
        'storno_am': _iso(DateTime.now()),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
