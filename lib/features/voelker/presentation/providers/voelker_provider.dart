import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/monitoring/data/models/scale.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
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

  /// Gibt den gespeicherten Standort MIT id zurueck — der Aufrufer braucht sie,
  /// um ihn direkt einem Volk zuzuordnen.
  Future<Standort> speichern(Standort s) async {
    final gespeichert = await _gw.standortSpeichern(s);
    ref.invalidateSelf();
    return gespeichert;
  }

  /// Loeschen: die DB setzt `voelker.standort_id` und `aufgaben.standort_id`
  /// per ON DELETE SET NULL auf null — Voelker und Aufgaben an diesem Stand
  /// verlieren ihn also. Deshalb beide Listen neu laden.
  Future<void> loeschen(String id) async {
    await _gw.standortLoeschen(id);
    ref.invalidateSelf();
    ref.invalidate(voelkerListProvider);
    ref.invalidate(aufgabenListProvider);
  }
}

class KoeniginnenNotifier extends AsyncNotifier<List<Koenigin>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Koenigin>> build() => _gw.koeniginnen();

  /// Gibt die gespeicherte Koenigin MIT id zurueck — der Aufrufer braucht sie,
  /// um sie direkt einem Volk zuzuordnen.
  Future<Koenigin> speichern(Koenigin k) async {
    final gespeichert = await _gw.koeniginSpeichern(k);
    ref.invalidateSelf();
    return gespeichert;
  }

  /// Loeschen: die DB setzt `voelker.koenigin_id` per ON DELETE SET NULL auf
  /// null — ein betroffenes Volk wird also weisellos. Deshalb auch die
  /// Voelker-Liste neu laden.
  Future<void> loeschen(String id) async {
    await _gw.koeniginLoeschen(id);
    ref.invalidateSelf();
    ref.invalidate(voelkerListProvider);
  }
}

class EinstellungenNotifier extends AsyncNotifier<BetriebsEinstellungen> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<BetriebsEinstellungen> build() async =>
      await _gw.einstellungen() ?? const BetriebsEinstellungen.leer();

  Future<void> speichern(BetriebsEinstellungen e) async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    await _gw.einstellungenSpeichern(betriebId, e);
    ref.invalidateSelf();
  }
}

/// Die Waage eines Volks (oder null). Filtert die bestehende scalesProvider-Liste,
/// kein Extra-Query.
final scaleFuerVolkProvider = Provider.family<Scale?, String>((ref, volkId) {
  final scales = ref.watch(scalesProvider).valueOrNull ?? const <Scale>[];
  for (final s in scales) {
    if (s.volkId == volkId) return s;
  }
  return null;
});
