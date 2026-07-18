import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/behandlung/data/supabase_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

final behandlungGatewayProvider =
    Provider<BehandlungGateway>((ref) => SupabaseBehandlungGateway(SupabaseConfig.client));

final kontrollenFuerVolkProvider =
    AsyncNotifierProvider.family<KontrollenNotifier, List<VarroaKontrolle>, String>(
        KontrollenNotifier.new);

final behandlungenFuerVolkProvider =
    AsyncNotifierProvider.family<BehandlungenNotifier, List<Behandlung>, String>(
        BehandlungenNotifier.new);

class KontrollenNotifier extends FamilyAsyncNotifier<List<VarroaKontrolle>, String> {
  BehandlungGateway get _gw => ref.read(behandlungGatewayProvider);
  @override
  Future<List<VarroaKontrolle>> build(String volkId) => _gw.kontrollenFuerVolk(volkId);

  Future<void> speichern(VarroaKontrolle k) async {
    await _gw.kontrolleSpeichern(k);
    ref.invalidateSelf();
  }

  Future<void> loeschen(String id) async {
    await _gw.kontrolleLoeschen(id);
    ref.invalidateSelf();
  }
}

class BehandlungenNotifier extends FamilyAsyncNotifier<List<Behandlung>, String> {
  BehandlungGateway get _gw => ref.read(behandlungGatewayProvider);
  @override
  Future<List<Behandlung>> build(String volkId) => _gw.behandlungenFuerVolk(volkId);

  Future<void> stornieren(String id, String grund) async {
    await _gw.behandlungStornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Sammelbehandlung: erfasst N Völker in einem RPC-Aufruf und invalidiert JEDE beteiligte
/// Volk-Family plus `materialListProvider` (Lager geändert). Bewusst NICHT am Notifier einer
/// einzelnen Family — die RPC schreibt über mehrere volk_ids, sonst blieben die anderen stale
/// (D-18/D-23-Fremd-Cache-Gotcha, hier intra-Mandant).
final behandlungAktionenProvider = Provider<BehandlungAktionen>((ref) => BehandlungAktionen(ref));

class BehandlungAktionen {
  final Ref _ref;
  BehandlungAktionen(this._ref);

  Future<int> erfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }) async {
    final n = await _ref.read(behandlungGatewayProvider).behandlungErfassen(
          volkIds: volkIds, datumBeginn: datumBeginn, datumEnde: datumEnde, praeparat: praeparat,
          wirkstoff: wirkstoff, mengeProVolk: mengeProVolk, einheit: einheit, konzentration: konzentration,
          anwendungsart: anwendungsart, indikation: indikation, aussentemperaturC: aussentemperaturC,
          wartefristTage: wartefristTage, charge: charge, verantwortlichePerson: verantwortlichePerson,
          materialId: materialId, notiz: notiz,
        );
    for (final id in volkIds.toSet()) {
      _ref.invalidate(behandlungenFuerVolkProvider(id));
    }
    _ref.invalidate(materialListProvider);
    return n;
  }
}
