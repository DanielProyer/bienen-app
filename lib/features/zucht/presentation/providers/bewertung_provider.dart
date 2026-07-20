import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/zucht/data/supabase_bewertung_gateway.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

final bewertungGatewayProvider =
    Provider<BewertungGateway>((ref) => SupabaseBewertungGateway(SupabaseConfig.client));

final bewertungenProvider =
    AsyncNotifierProvider<BewertungNotifier, List<VolkBewertung>>(BewertungNotifier.new);

class BewertungNotifier extends AsyncNotifier<List<VolkBewertung>> {
  BewertungGateway get _gw => ref.read(bewertungGatewayProvider);
  @override
  Future<List<VolkBewertung>> build() => _gw.alle();
  Future<void> speichern(VolkBewertung b) async { await _gw.speichern(b); ref.invalidateSelf(); }
  Future<void> loeschen(String id) async { await _gw.loeschen(id); ref.invalidateSelf(); }
}

/// Bewertungen eines Volks (neueste zuerst) — reine Ableitung.
final bewertungenFuerVolkProvider = Provider.family<List<VolkBewertung>, String>((ref, volkId) {
  final list = ref.watch(bewertungenProvider).valueOrNull ?? const [];
  return list.where((b) => b.volkId == volkId).toList()
    ..sort((a, b) => b.bewertetAm.compareTo(a.bewertetAm));
});
