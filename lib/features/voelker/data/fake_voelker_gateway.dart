import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

/// In-Memory-Gateway fuer Tests (kein Netz). Bildet die harten DB-Invarianten
/// nach: 1 Koenigin -> hoechstens 1 Volk (BA022).
class FakeVoelkerGateway implements VoelkerGateway {
  final _voelker = <String, Volk>{};
  final _standorte = <String, Standort>{};
  final _koeniginnen = <String, Koenigin>{};
  BetriebsEinstellungen? einstellungenWert;
  int _seq = 0;

  @override
  Future<List<Volk>> voelker() async => _voelker.values
      .map((v) => Volk(
            id: v.id, name: v.name, status: v.status, standortId: v.standortId,
            koeniginId: v.koeniginId, mutterVolkId: v.mutterVolkId, beutentyp: v.beutentyp,
            zargen: v.zargen, brutwaben: v.brutwaben, bioStatus: v.bioStatus,
            gesundheitsstatus: v.gesundheitsstatus, einweiselungAm: v.einweiselungAm,
            herkunft: v.herkunft, notes: v.notes, sortOrder: v.sortOrder,
            koenigin: v.koeniginId != null ? _koeniginnen[v.koeniginId] : null,
            standort: v.standortId != null ? _standorte[v.standortId] : null,
          ))
      .toList();

  @override
  Future<List<Standort>> standorte() async => _standorte.values.toList();
  @override
  Future<List<Koenigin>> koeniginnen() async => _koeniginnen.values.toList();
  @override
  Future<BetriebsEinstellungen?> einstellungen() async => einstellungenWert;
  @override
  Future<void> einstellungenSpeichern(String betriebId, BetriebsEinstellungen e) async {
    einstellungenWert = e;
  }

  @override
  Future<void> volkSpeichern(Volk volk) async {
    if (volk.koeniginId != null) {
      final belegt = _voelker.values.any((v) => v.id != volk.id && v.koeniginId == volk.koeniginId);
      if (belegt) {
        throw const VoelkerFehler('BA022', 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.');
      }
    }
    final id = volk.id.isEmpty ? 'v${++_seq}' : volk.id;
    _voelker[id] = Volk(
      id: id, name: volk.name, status: volk.status, standortId: volk.standortId,
      koeniginId: volk.koeniginId, mutterVolkId: volk.mutterVolkId, beutentyp: volk.beutentyp,
      zargen: volk.zargen, brutwaben: volk.brutwaben, bioStatus: volk.bioStatus,
      gesundheitsstatus: volk.gesundheitsstatus, einweiselungAm: volk.einweiselungAm,
      herkunft: volk.herkunft, notes: volk.notes, sortOrder: volk.sortOrder,
    );
  }

  @override
  Future<void> volkLoeschen(String id) async => _voelker.remove(id);

  @override
  Future<void> standortSpeichern(Standort s) async {
    final id = s.id.isEmpty ? 's${++_seq}' : s.id;
    _standorte[id] = Standort(
      id: id, name: s.name, adresse: s.adresse, parzelle: s.parzelle, gpsLat: s.gpsLat,
      gpsLng: s.gpsLng, hoeheM: s.hoeheM, kanton: s.kanton, amtlicheStandnummer: s.amtlicheStandnummer,
      inspektionskreis: s.inspektionskreis, status: s.status, aufgeloestAm: s.aufgeloestAm,
      trachtnotiz: s.trachtnotiz, sperrbezirk: s.sperrbezirk, notes: s.notes, sortOrder: s.sortOrder,
    );
  }

  @override
  Future<Koenigin> koeniginSpeichern(Koenigin k) async {
    final id = k.id.isEmpty ? 'k${++_seq}' : k.id;
    final gespeichert = Koenigin(
      id: id, kennung: k.kennung, schlupfjahr: k.schlupfjahr, rasse: k.rasse, linie: k.linie,
      herkunft: k.herkunft, begattungsart: k.begattungsart, status: k.status, volkId: k.volkId,
      zugeordnetAm: k.zugeordnetAm, ersetztAm: k.ersetztAm, mutterKoeniginId: k.mutterKoeniginId,
      notes: k.notes,
    );
    _koeniginnen[id] = gespeichert;
    return gespeichert;
  }

  @override
  Future<void> koeniginLoeschen(String id) async {
    _koeniginnen.remove(id);
    // Volk, das diese Koenigin trug, wird weisellos (wie ON DELETE SET NULL in der DB).
    // ALLE uebrigen Felder muessen erhalten bleiben — Volk hat kein copyWith.
    for (final v in _voelker.values.toList()) {
      if (v.koeniginId == id) {
        _voelker[v.id] = Volk(
          id: v.id, name: v.name, status: v.status, standortId: v.standortId,
          koeniginId: null, mutterVolkId: v.mutterVolkId, beutentyp: v.beutentyp,
          zargen: v.zargen, brutwaben: v.brutwaben, bioStatus: v.bioStatus,
          gesundheitsstatus: v.gesundheitsstatus, einweiselungAm: v.einweiselungAm,
          herkunft: v.herkunft, notes: v.notes, sortOrder: v.sortOrder,
          koenigin: null, standort: v.standort,
        );
      }
    }
  }

  @override
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  }) async {
    final v = _voelker[volkId];
    if (v == null) throw const VoelkerFehler('BA020', 'Volk nicht gefunden.');
    if (neueKoeniginId != null) {
      final belegt = _voelker.values.any((x) => x.id != volkId && x.koeniginId == neueKoeniginId);
      if (belegt) {
        throw const VoelkerFehler('BA022', 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.');
      }
    }
    final tag = datum ?? DateTime.now();
    if (v.koeniginId != null) {
      final alt = _koeniginnen[v.koeniginId]!;
      _koeniginnen[alt.id] = Koenigin(
        id: alt.id, kennung: alt.kennung, schlupfjahr: alt.schlupfjahr, rasse: alt.rasse,
        linie: alt.linie, herkunft: alt.herkunft, begattungsart: alt.begattungsart,
        status: altGrund, volkId: alt.volkId, zugeordnetAm: alt.zugeordnetAm, ersetztAm: tag,
        mutterKoeniginId: alt.mutterKoeniginId, notes: alt.notes,
      );
    }
    if (neueKoeniginId != null) {
      final neu = _koeniginnen[neueKoeniginId]!;
      _koeniginnen[neu.id] = Koenigin(
        id: neu.id, kennung: neu.kennung, schlupfjahr: neu.schlupfjahr, rasse: neu.rasse,
        linie: neu.linie, herkunft: neu.herkunft, begattungsart: neu.begattungsart,
        status: 'aktiv', volkId: volkId, zugeordnetAm: tag, ersetztAm: null,
        mutterKoeniginId: neu.mutterKoeniginId, notes: neu.notes,
      );
    }
    _voelker[volkId] = Volk(
      id: v.id, name: v.name, status: v.status, standortId: v.standortId,
      koeniginId: neueKoeniginId, mutterVolkId: v.mutterVolkId, beutentyp: v.beutentyp,
      zargen: v.zargen, brutwaben: v.brutwaben, bioStatus: v.bioStatus,
      gesundheitsstatus: v.gesundheitsstatus, einweiselungAm: v.einweiselungAm,
      herkunft: v.herkunft, notes: v.notes, sortOrder: v.sortOrder,
    );
  }
}
