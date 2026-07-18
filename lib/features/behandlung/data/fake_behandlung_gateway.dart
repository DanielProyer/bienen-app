import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';

/// In-Memory-Fake, der die Server-Semantik der RPC nachbildet (distinct-Insert, Lager-Abbuchung
/// aus real erzeugter Zeilenzahl, BA030/031/032/033, Einweg-Storno/BA034). Ohne diese Treue
/// wären die Provider-/UI-Tests blind für genau die Invarianten, die den amtlichen Daten Sicherheit geben.
class FakeBehandlungGateway implements BehandlungGateway {
  final _kontrollen = <String, VarroaKontrolle>{};
  final _behandlungen = <String, Behandlung>{};
  final lagerBestand = <String, double>{}; // Material-Sim: id -> stock_qty
  int _seq = 0;

  List<VarroaKontrolle> get _kSort {
    final l = _kontrollen.values.toList();
    l.sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));
    return l;
  }

  List<Behandlung> get _bSort {
    final l = _behandlungen.values.toList();
    l.sort((a, b) => b.datumBeginn.compareTo(a.datumBeginn));
    return l;
  }

  @override
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId) async =>
      _kSort.where((k) => k.volkId == volkId).toList();

  @override
  Future<void> kontrolleSpeichern(VarroaKontrolle k) async {
    final id = k.id.isEmpty ? 'k${++_seq}' : k.id;
    _kontrollen[id] = VarroaKontrolle(
      id: id, volkId: k.volkId, durchgefuehrtAm: k.durchgefuehrtAm, methode: k.methode,
      messdauerTage: k.messdauerTage, milbenGesamt: k.milbenGesamt, bienenProbe: k.bienenProbe, notiz: k.notiz,
    );
  }

  @override
  Future<void> kontrolleLoeschen(String id) async => _kontrollen.remove(id);

  @override
  Future<List<Behandlung>> behandlungenFuerVolk(String volkId) async =>
      _bSort.where((b) => b.volkId == volkId).toList();

  @override
  Future<int> behandlungErfassen({
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
    final biotech = Anwendungsart.ohneChemie.contains(anwendungsart);
    if (volkIds.isEmpty) throw const BehandlungFehler('BA031', 'Keine Völker angegeben');
    if (verantwortlichePerson.trim().isEmpty ||
        (!biotech && (praeparat == null || praeparat.trim().isEmpty))) {
      throw const BehandlungFehler('BA030', 'Pflichtfeld fehlt');
    }
    if (!biotech && (mengeProVolk == null || mengeProVolk <= 0 || einheit == null)) {
      throw const BehandlungFehler('BA033', 'Menge/Einheit bei chemischer Anwendung Pflicht');
    }
    final distinct = volkIds.toSet().toList();
    for (final v in distinct) {
      final id = 'b${++_seq}';
      _behandlungen[id] = Behandlung(
        id: id, volkId: v, datumBeginn: datumBeginn, datumEnde: datumEnde, praeparat: praeparat,
        wirkstoff: wirkstoff, mengeProVolk: mengeProVolk, einheit: einheit, konzentration: konzentration,
        anwendungsart: anwendungsart, indikation: indikation ?? 'Varroabekämpfung',
        aussentemperaturC: aussentemperaturC, wartefristTage: wartefristTage, charge: charge,
        verantwortlichePerson: verantwortlichePerson, materialId: materialId, notiz: notiz,
      );
    }
    if (materialId != null && lagerBestand.containsKey(materialId)) {
      lagerBestand[materialId] = lagerBestand[materialId]! - (mengeProVolk ?? 0) * distinct.length;
    }
    return distinct.length;
  }

  @override
  Future<void> behandlungStornieren(String id, String grund) async {
    final b = _behandlungen[id];
    if (b == null) return;
    if (b.isStorniert) throw const BehandlungFehler('BA034', 'Storno ist terminal');
    _behandlungen[id] = Behandlung(
      id: b.id, volkId: b.volkId, datumBeginn: b.datumBeginn, datumEnde: b.datumEnde, praeparat: b.praeparat,
      wirkstoff: b.wirkstoff, mengeProVolk: b.mengeProVolk, einheit: b.einheit, konzentration: b.konzentration,
      anwendungsart: b.anwendungsart, indikation: b.indikation, aussentemperaturC: b.aussentemperaturC,
      wartefristTage: b.wartefristTage, charge: b.charge, verantwortlichePerson: b.verantwortlichePerson,
      materialId: b.materialId, isStorniert: true, stornoGrund: grund, stornoAm: b.datumBeginn, notiz: b.notiz,
    );
  }
}
