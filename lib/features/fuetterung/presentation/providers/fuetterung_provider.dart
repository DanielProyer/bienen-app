import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/fuetterung/data/supabase_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

final fuetterungGatewayProvider =
    Provider<FuetterungGateway>((ref) => SupabaseFuetterungGateway(SupabaseConfig.client));

final fuetterungenFuerVolkProvider =
    AsyncNotifierProvider.family<FuetterungenNotifier, List<Fuetterung>, String>(
        FuetterungenNotifier.new);

class FuetterungenNotifier extends FamilyAsyncNotifier<List<Fuetterung>, String> {
  FuetterungGateway get _gw => ref.read(fuetterungGatewayProvider);
  @override
  Future<List<Fuetterung>> build(String volkId) => _gw.fuetterungenFuerVolk(volkId);

  Future<void> stornieren(String id, String grund) async {
    await _gw.fuetterungStornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Sammelfütterung: erfasst N Völker in einem RPC-Aufruf und invalidiert JEDE beteiligte
/// Volk-Family plus `materialListProvider` (Lager geändert). Wie 4.5 (D-18/D-23-Gotcha).
final fuetterungAktionenProvider = Provider<FuetterungAktionen>((ref) => FuetterungAktionen(ref));

class FuetterungAktionen {
  final Ref _ref;
  FuetterungAktionen(this._ref);

  Future<int> erfassen({
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
    final n = await _ref.read(fuetterungGatewayProvider).fuetterungErfassen(
          volkIds: volkIds, durchgefuehrtAm: durchgefuehrtAm, zweck: zweck, futterart: futterart,
          bioZertifiziert: bioZertifiziert, mengeProVolkKg: mengeProVolkKg, materialId: materialId,
          verantwortlichePerson: verantwortlichePerson, notiz: notiz,
        );
    for (final id in volkIds.toSet()) {
      _ref.invalidate(fuetterungenFuerVolkProvider(id));
    }
    _ref.invalidate(materialListProvider);
    return n;
  }
}
