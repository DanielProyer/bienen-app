import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

class FuetterungFehler implements Exception {
  final String code;
  final String message;
  const FuetterungFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class FuetterungGateway {
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId); // inkl. stornierte, absteigend
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
  }); // -> Anzahl erzeugter Eintraege
  Future<void> fuetterungStornieren(String id, String grund);
}
