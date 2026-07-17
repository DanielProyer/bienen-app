import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/voelker/data/supabase_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

final voelkerGatewayProvider =
    Provider<VoelkerGateway>((ref) => SupabaseVoelkerGateway(SupabaseConfig.client));

final voelkerListProvider =
    AsyncNotifierProvider<VoelkerListNotifier, List<Volk>>(VoelkerListNotifier.new);
final standorteProvider =
    AsyncNotifierProvider<StandorteNotifier, List<Standort>>(StandorteNotifier.new);
final koeniginnenProvider =
    AsyncNotifierProvider<KoeniginnenNotifier, List<Koenigin>>(KoeniginnenNotifier.new);
final betriebsEinstellungenProvider =
    AsyncNotifierProvider<EinstellungenNotifier, BetriebsEinstellungen>(EinstellungenNotifier.new);

/// Nur aktive Voelker, sortiert (Default-Ansicht der Liste).
final aktiveVoelkerProvider = Provider<List<Volk>>((ref) {
  final v = ref.watch(voelkerListProvider).valueOrNull ?? [];
  return v.where((x) => x.status == 'aktiv').toList()
    ..sort((a, b) => a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.name.compareTo(b.name));
});

class VoelkerListNotifier extends AsyncNotifier<List<Volk>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Volk>> build() => _gw.voelker();
  Future<void> speichern(Volk v) async { await _gw.volkSpeichern(v); ref.invalidateSelf(); }
  Future<void> loeschen(String id) async { await _gw.volkLoeschen(id); ref.invalidateSelf(); }
  Future<void> umweiseln({
    required String volkId, String? neueKoeniginId,
    String altGrund = 'ersetzt', DateTime? datum,
  }) async {
    await _gw.umweiseln(volkId: volkId, neueKoeniginId: neueKoeniginId, altGrund: altGrund, datum: datum);
    ref.invalidateSelf();
    ref.invalidate(koeniginnenProvider);
  }
}

class StandorteNotifier extends AsyncNotifier<List<Standort>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Standort>> build() => _gw.standorte();
  Future<void> speichern(Standort s) async { await _gw.standortSpeichern(s); ref.invalidateSelf(); }
}

class KoeniginnenNotifier extends AsyncNotifier<List<Koenigin>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Koenigin>> build() => _gw.koeniginnen();
  Future<void> speichern(Koenigin k) async { await _gw.koeniginSpeichern(k); ref.invalidateSelf(); }
}

class EinstellungenNotifier extends AsyncNotifier<BetriebsEinstellungen> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<BetriebsEinstellungen> build() async =>
      await _gw.einstellungen() ?? const BetriebsEinstellungen.leer();
}
