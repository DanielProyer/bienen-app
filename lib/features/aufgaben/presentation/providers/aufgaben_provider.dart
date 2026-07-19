import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/aufgaben/data/supabase_aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final aufgabenGatewayProvider =
    Provider<AufgabenGateway>((ref) => SupabaseAufgabenGateway(SupabaseConfig.client));

final aufgabenListProvider =
    AsyncNotifierProvider<AufgabenNotifier, List<Aufgabe>>(AufgabenNotifier.new);

class AufgabenNotifier extends AsyncNotifier<List<Aufgabe>> {
  AufgabenGateway get _gw => ref.read(aufgabenGatewayProvider);
  @override
  Future<List<Aufgabe>> build() => _gw.alle();

  Future<void> speichern(Aufgabe a) async {
    await _gw.speichern(a);
    ref.invalidateSelf();
  }

  Future<void> loeschen(String id) async {
    await _gw.loeschen(id);
    ref.invalidateSelf();
  }

  Future<void> abhaken(String id, {bool erledigt = true}) async {
    await _gw.setzeStatus(id, erledigt ? 'erledigt' : 'offen',
        erledigtAm: erledigt ? DateTime.now() : null);
    ref.invalidateSelf();
  }

  Aufgabe _ausVorschlag(AufgabenVorschlag v, {String? volkId, String status = 'offen'}) => Aufgabe(
        id: '', titel: v.regel.titel, beschreibung: v.regel.beschreibung,
        kategorie: v.regel.kategorie, faelligAm: v.faelligAm, status: status,
        volkId: volkId, quelle: 'regel', regelKey: v.regel.key, saisonJahr: v.saisonJahr,
      );

  /// ebene=volk: eine Zeile je [volkIds]; ebene=betrieb: volkIds ignorieren (eine Zeile).
  Future<void> vorschlagAnnehmen(AufgabenVorschlag v, {List<String> volkIds = const []}) async {
    final rows = v.regel.ebene == RegelEbene.volk
        ? volkIds.map((id) => _ausVorschlag(v, volkId: id)).toList()
        : [_ausVorschlag(v)];
    await _gw.speichernBatch(rows);
    ref.invalidateSelf();
  }

  /// Überspringen dedupt die Regel fürs ganze Saisonjahr (eine Zeile OHNE volk_id).
  Future<void> vorschlagUeberspringen(AufgabenVorschlag v) async {
    await _gw.speichernBatch([_ausVorschlag(v, status: 'uebersprungen')]);
    ref.invalidateSelf();
  }
}

/// Offene Aufgaben eines Volks (reine Ableitung — kein eigener Fetch, D-18/D-23-sicher).
final aufgabenFuerVolkProvider = Provider.family<List<Aufgabe>, String>((ref, volkId) {
  final list = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
  return list.where((a) => a.istOffen && a.volkId == volkId).toList();
});

/// Dashboard-Kachel: offene + überfällige Anzahl.
final offeneAufgabenStatsProvider = Provider<({int offen, int ueberfaellig})>((ref) {
  final list = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
  final heute = DateTime.now();
  final h = DateTime(heute.year, heute.month, heute.day);
  final offen = list.where((a) => a.istOffen).toList();
  final ueberfaellig = offen.where((a) => a.faelligAm.isBefore(h)).length;
  return (offen: offen.length, ueberfaellig: ueberfaellig);
});

/// Generator-Vorschläge (Liste + Einstellungen + aktive Völker kombiniert).
final vorschlaegeProvider = Provider<List<AufgabenVorschlag>>((ref) {
  final aufgaben = ref.watch(aufgabenListProvider).valueOrNull;
  final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
  if (aufgaben == null || einst == null) return const [];
  final aktive = ref.watch(aktiveVoelkerProvider);
  return anstehendeVorschlaege(
    stichtag: DateTime.now(),
    saisonOffsetTage: einst.saisonOffsetDefaultTage,
    regelAufgaben: aufgaben.where((a) => a.quelle == 'regel').toList(),
    anzahlAktiveVoelker: aktive.length,
  );
});
