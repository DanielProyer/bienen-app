import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/data/supabase_vermehrung_gateway.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final vermehrungGatewayProvider =
    Provider<VermehrungGateway>((ref) => SupabaseVermehrungGateway(SupabaseConfig.client));

final vermehrungListProvider =
    AsyncNotifierProvider<VermehrungNotifier, List<VermehrungsEreignis>>(VermehrungNotifier.new);

class VermehrungNotifier extends AsyncNotifier<List<VermehrungsEreignis>> {
  VermehrungGateway get _gw => ref.read(vermehrungGatewayProvider);
  @override
  Future<List<VermehrungsEreignis>> build() => _gw.alle();
  Future<void> speichern(VermehrungsEreignis e) async {
    await _gw.speichern(e);
    ref.invalidateSelf();
  }

  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    await _gw.jungvolkVerknuepfen(id, jungvolkId);
    ref.invalidateSelf();
  }

  Future<void> loeschen(String id) async {
    await _gw.loeschen(id);
    ref.invalidateSelf();
    ref.invalidate(aufgabenListProvider); // FK ON DELETE CASCADE hat Ketten-Aufgaben entfernt
  }
}

/// Ketten-Vorschläge (Vermehrung) für den Aufgaben-Tab.
final kettenVorschlaegeProvider = Provider<List<KettenVorschlag>>((ref) {
  final ereignisse = ref.watch(vermehrungListProvider).valueOrNull;
  final aufgaben = ref.watch(aufgabenListProvider).valueOrNull;
  if (ereignisse == null || aufgaben == null) return const [];
  final aktiv = ref.watch(aktiveVoelkerProvider).map((v) => v.id).toSet();
  return kettenVorschlaege(
    stichtag: DateTime.now(),
    ereignisse: ereignisse,
    kettenAufgaben: aufgaben.where((a) => a.quelle == 'ereignis').toList(),
    aktiveVolkIds: aktiv,
  );
});
