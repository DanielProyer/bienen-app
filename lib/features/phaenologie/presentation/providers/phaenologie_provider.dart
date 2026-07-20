import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/phaenologie/data/supabase_phaenologie_gateway.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

final phaenologieGatewayProvider =
    Provider<PhaenologieGateway>((ref) => SupabasePhaenologieGateway(SupabaseConfig.client));

final phaenologieProvider =
    AsyncNotifierProvider<PhaenologieNotifier, List<PhaenoBeobachtung>>(PhaenologieNotifier.new);

class PhaenologieNotifier extends AsyncNotifier<List<PhaenoBeobachtung>> {
  PhaenologieGateway get _gw => ref.read(phaenologieGatewayProvider);
  @override
  Future<List<PhaenoBeobachtung>> build() => _gw.alle();

  Future<void> speichern(PhaenoBeobachtung b) async {
    await _gw.upsert(b);
    ref.invalidateSelf();
  }
}
