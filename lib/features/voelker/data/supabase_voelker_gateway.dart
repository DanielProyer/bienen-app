import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

class SupabaseVoelkerGateway implements VoelkerGateway {
  final SupabaseClient _c;
  SupabaseVoelkerGateway(this._c);

  static const _klartext = <String, String>{
    'BA020': 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb.',
    'BA021': 'Koenigin nicht gefunden oder gehoert nicht zu deinem Betrieb.',
    'BA022': 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.',
    'BA023': 'Ungueltiger Grund fuer die alte Koenigin.',
    '23505': 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.',
  };

  Never _rethrow(Object e) {
    if (e is PostgrestException && _klartext.containsKey(e.code)) {
      throw VoelkerFehler(e.code!, _klartext[e.code]!);
    }
    throw e;
  }

  @override
  Future<List<Volk>> voelker() async {
    try {
      final res = await _c
          .from('voelker')
          .select('*, koenigin:koeniginnen!voelker_koenigin_fk(*), standort:standorte!voelker_standort_fk(*)')
          .order('sort_order', ascending: true);
      return (res as List).map((j) => Volk.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Standort>> standorte() async {
    final res = await _c.from('standorte').select().order('sort_order', ascending: true);
    return (res as List).map((j) => Standort.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Koenigin>> koeniginnen() async {
    final res = await _c.from('koeniginnen').select().order('schlupfjahr', ascending: false);
    return (res as List).map((j) => Koenigin.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<BetriebsEinstellungen?> einstellungen() async {
    final res = await _c.from('betriebs_einstellungen').select().maybeSingle();
    return res == null ? null : BetriebsEinstellungen.fromJson(res);
  }

  @override
  Future<void> volkSpeichern(Volk volk) async {
    try {
      final json = volk.toInsertJson();
      if (volk.id.isEmpty) {
        await _c.from('voelker').insert(json);
      } else {
        await _c.from('voelker').update(json).eq('id', volk.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> volkLoeschen(String id) async {
    await _c.from('voelker').delete().eq('id', id);
  }

  @override
  Future<void> standortSpeichern(Standort s) async {
    try {
      final json = s.toInsertJson();
      if (s.id.isEmpty) {
        await _c.from('standorte').insert(json);
      } else {
        await _c.from('standorte').update(json).eq('id', s.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> koeniginSpeichern(Koenigin k) async {
    try {
      final json = k.toInsertJson();
      if (k.id.isEmpty) {
        await _c.from('koeniginnen').insert(json);
      } else {
        await _c.from('koeniginnen').update(json).eq('id', k.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  }) async {
    try {
      await _c.rpc('volk_umweiseln', params: {
        'p_volk_id': volkId,
        'p_neue_koenigin_id': neueKoeniginId,
        'p_alt_grund': altGrund,
        if (datum != null) 'p_datum': datum.toIso8601String().substring(0, 10),
      });
    } catch (e) {
      _rethrow(e);
    }
  }
}
