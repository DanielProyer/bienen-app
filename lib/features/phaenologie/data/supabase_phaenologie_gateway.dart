import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

class SupabasePhaenologieGateway implements PhaenologieGateway {
  final SupabaseClient _c;
  SupabasePhaenologieGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw PhaenologieFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<PhaenoBeobachtung>> alle() async {
    try {
      final res = await _c.from('phaenologie_beobachtungen').select();
      return (res as List)
          .map((j) => PhaenoBeobachtung.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> upsert(PhaenoBeobachtung b) async {
    try {
      await _c
          .from('phaenologie_beobachtungen')
          .upsert(b.toUpsertJson(), onConflict: 'betrieb_id,jahr,anker');
    } catch (e) {
      _rethrow(e);
    }
  }
}
