import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

class SupabaseBehandlungGateway implements BehandlungGateway {
  final SupabaseClient _c;
  SupabaseBehandlungGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw BehandlungFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('varroa_kontrollen')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => VarroaKontrolle.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> kontrolleSpeichern(VarroaKontrolle k) async {
    try {
      final json = k.toInsertJson();
      if (k.id.isEmpty) {
        await _c.from('varroa_kontrollen').insert(json);
      } else {
        await _c.from('varroa_kontrollen').update(json).eq('id', k.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> kontrolleLoeschen(String id) async {
    try {
      await _c.from('varroa_kontrollen').delete().eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Behandlung>> behandlungenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('behandlungen')
          .select()
          .eq('volk_id', volkId)
          .order('datum_beginn', ascending: false);
      return (res as List).map((j) => Behandlung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  String? _iso(DateTime? d) => d == null ? null : d.toIso8601String().substring(0, 10);

  @override
  Future<int> behandlungErfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }) async {
    try {
      final n = await _c.rpc('behandlung_erfassen', params: {
        'p_volk_ids': volkIds,
        'p_datum_beginn': _iso(datumBeginn),
        'p_wirkstoff': wirkstoff,
        'p_anwendungsart': anwendungsart,
        'p_verantwortliche_person': verantwortlichePerson,
        'p_datum_ende': _iso(datumEnde),
        'p_praeparat': praeparat,
        'p_menge_pro_volk': mengeProVolk,
        'p_einheit': einheit,
        'p_konzentration': konzentration,
        'p_indikation': indikation,
        'p_aussentemperatur_c': aussentemperaturC,
        'p_wartefrist_tage': wartefristTage,
        'p_charge': charge,
        'p_material_id': materialId,
        'p_notiz': notiz,
      });
      return (n as num).toInt();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> behandlungStornieren(String id, String grund) async {
    try {
      await _c.from('behandlungen').update({'is_storniert': true, 'storno_grund': grund}).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
