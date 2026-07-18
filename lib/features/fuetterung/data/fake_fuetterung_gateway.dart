import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

/// In-Memory-Fake, bildet die RPC-Semantik nach (distinct-Insert, Lager-Abbuchung × v_n,
/// BA040/041/042). Storno terminal (BA040), damit die Tests die Invarianten sehen.
class FakeFuetterungGateway implements FuetterungGateway {
  final _map = <String, Fuetterung>{};
  final lagerBestand = <String, double>{};
  int _seq = 0;

  List<Fuetterung> get _sort {
    final l = _map.values.toList();
    l.sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));
    return l;
  }

  @override
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId) async =>
      _sort.where((f) => f.volkId == volkId).toList();

  @override
  Future<int> fuetterungErfassen({
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
    if (volkIds.isEmpty) throw const FuetterungFehler('BA041', 'Keine Völker angegeben');
    if (!Zweck.werte.contains(zweck) ||
        !Futterart.werte.contains(futterart) ||
        mengeProVolkKg <= 0) {
      throw const FuetterungFehler('BA040', 'Pflichtfeld fehlt oder ungültig');
    }
    final distinct = volkIds.toSet().toList();
    for (final v in distinct) {
      final id = 'f${++_seq}';
      _map[id] = Fuetterung(
        id: id, volkId: v, durchgefuehrtAm: durchgefuehrtAm, zweck: zweck, futterart: futterart,
        bioZertifiziert: bioZertifiziert, mengeProVolkKg: mengeProVolkKg, materialId: materialId,
        verantwortlichePerson: verantwortlichePerson, notiz: notiz,
      );
    }
    if (materialId != null && lagerBestand.containsKey(materialId)) {
      lagerBestand[materialId] = lagerBestand[materialId]! - mengeProVolkKg.toDouble() * distinct.length;
    }
    return distinct.length;
  }

  @override
  Future<void> fuetterungStornieren(String id, String grund) async {
    final f = _map[id];
    if (f == null) return;
    if (f.isStorniert) throw const FuetterungFehler('BA040', 'Storno ist terminal');
    _map[id] = Fuetterung(
      id: f.id, volkId: f.volkId, durchgefuehrtAm: f.durchgefuehrtAm, zweck: f.zweck,
      futterart: f.futterart, bioZertifiziert: f.bioZertifiziert, mengeProVolkKg: f.mengeProVolkKg,
      materialId: f.materialId, verantwortlichePerson: f.verantwortlichePerson,
      isStorniert: true, stornoGrund: grund, stornoAm: f.durchgefuehrtAm, notiz: f.notiz,
    );
  }
}
