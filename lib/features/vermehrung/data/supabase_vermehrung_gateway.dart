import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';

class SupabaseVermehrungGateway implements VermehrungGateway {
  final SupabaseClient _c;
  SupabaseVermehrungGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw VermehrungFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<VermehrungsEreignis>> alle() async {
    try {
      final res = await _c.from('vermehrungs_ereignisse').select().order('erstellt_am', ascending: false);
      return (res as List).map((j) => VermehrungsEreignis.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichern(VermehrungsEreignis e) async {
    try {
      final json = e.toInsertJson();
      if (e.id.isEmpty) {
        await _c.from('vermehrungs_ereignisse').insert(json);
      } else {
        await _c.from('vermehrungs_ereignisse').update(json).eq('id', e.id);
      }
    } catch (err) {
      _rethrow(err);
    }
  }

  @override
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    try {
      await _c.from('vermehrungs_ereignisse').update({'jungvolk_id': jungvolkId}).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> loeschen(String id) async {
    try {
      await _c.from('vermehrungs_ereignisse').delete().eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
