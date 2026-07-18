import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

class BehandlungFehler implements Exception {
  final String code;
  final String message;
  const BehandlungFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class BehandlungGateway {
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId); // absteigend nach Datum
  Future<void> kontrolleSpeichern(VarroaKontrolle k); // insert wenn id leer, sonst update
  Future<void> kontrolleLoeschen(String id);

  Future<List<Behandlung>> behandlungenFuerVolk(String volkId); // inkl. stornierte, absteigend
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
  }); // -> Anzahl erzeugter Eintraege
  Future<void> behandlungStornieren(String id, String grund);
}
