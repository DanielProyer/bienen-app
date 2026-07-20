import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

class SupabaseBewertungGateway implements BewertungGateway {
  final SupabaseClient _c;
  SupabaseBewertungGateway(this._c);
  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) throw BewertungFehler(e.code!, e.message);
    throw e;
  }
  @override
  Future<List<VolkBewertung>> alle() async {
    try {
      final res = await _c.from('volk_bewertungen').select().order('bewertet_am', ascending: false);
      return (res as List).map((j) => VolkBewertung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> speichern(VolkBewertung b) async {
    try {
      final json = b.toInsertJson();
      if (b.id.isEmpty) {
        await _c.from('volk_bewertungen').insert(json);
      } else {
        await _c.from('volk_bewertungen').update(json).eq('id', b.id);
      }
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> loeschen(String id) async {
    try { await _c.from('volk_bewertungen').delete().eq('id', id); } catch (e) { _rethrow(e); }
  }
}
