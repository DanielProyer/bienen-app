import 'package:bienen_app/features/zucht/domain/bewertung.dart';

class BewertungFehler implements Exception {
  final String code; final String message;
  const BewertungFehler(this.code, this.message);
  @override String toString() => message;
}

abstract class BewertungGateway {
  Future<List<VolkBewertung>> alle();
  Future<void> speichern(VolkBewertung b); // insert wenn id leer, sonst update
  Future<void> loeschen(String id);
}
