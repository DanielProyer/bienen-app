import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/gesundheit/data/supabase_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

final gesundheitGatewayProvider =
    Provider<GesundheitGateway>((ref) => SupabaseGesundheitGateway(SupabaseConfig.client));

final gesundheitFuerVolkProvider =
    AsyncNotifierProvider.family<GesundheitNotifier, List<Gesundheitsereignis>, String>(
        GesundheitNotifier.new);

class GesundheitNotifier extends FamilyAsyncNotifier<List<Gesundheitsereignis>, String> {
  GesundheitGateway get _gw => ref.read(gesundheitGatewayProvider);
  @override
  Future<List<Gesundheitsereignis>> build(String volkId) => _gw.ereignisseFuerVolk(volkId);

  Future<void> speichern(Gesundheitsereignis e) async {
    await _gw.speichern(e);
    ref.invalidateSelf();
  }

  Future<void> stornieren(String id, String grund) async {
    await _gw.stornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Aktive meldepflichtige Ereignisse (zu_bekaempfen + neobiota) fürs Melde-Banner (reine Ableitung — refresht nach Storno/Status).
final aktiveMeldepflichtProvider = Provider.family<List<Gesundheitsereignis>, String>((ref, volkId) {
  final list = ref.watch(gesundheitFuerVolkProvider(volkId)).valueOrNull ?? const [];
  return list.where((e) => e.istAktiv && istMeldepflichtig(e.krankheit)).toList();
});
