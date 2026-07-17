import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/durchsicht/data/supabase_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

final durchsichtGatewayProvider =
    Provider<DurchsichtGateway>((ref) => SupabaseDurchsichtGateway(SupabaseConfig.client));

final durchsichtenFuerVolkProvider =
    AsyncNotifierProvider.family<DurchsichtenNotifier, List<Durchsicht>, String>(
        DurchsichtenNotifier.new);

final letzteDurchsichtenProvider =
    AsyncNotifierProvider<LetzteDurchsichtenNotifier, List<Durchsicht>>(
        LetzteDurchsichtenNotifier.new);

/// Letzte Durchsicht je volkId (gemappt) fuer die VolkCard.
final letzteDurchsichtMapProvider = Provider<Map<String, Durchsicht>>((ref) {
  final list = ref.watch(letzteDurchsichtenProvider).valueOrNull ?? const [];
  return {for (final d in list) d.volkId: d};
});

class DurchsichtenNotifier extends FamilyAsyncNotifier<List<Durchsicht>, String> {
  DurchsichtGateway get _gw => ref.read(durchsichtGatewayProvider);
  @override
  Future<List<Durchsicht>> build(String volkId) => _gw.fuerVolk(volkId);

  Future<void> speichern(Durchsicht d) async {
    await _gw.speichern(d);
    ref.invalidateSelf();
    ref.invalidate(letzteDurchsichtenProvider);
  }

  Future<void> loeschen(Durchsicht d) async {
    await _gw.loeschen(d);
    ref.invalidateSelf();
    ref.invalidate(letzteDurchsichtenProvider);
  }
}

class LetzteDurchsichtenNotifier extends AsyncNotifier<List<Durchsicht>> {
  @override
  Future<List<Durchsicht>> build() => ref.read(durchsichtGatewayProvider).letzteJeVolk();
}
