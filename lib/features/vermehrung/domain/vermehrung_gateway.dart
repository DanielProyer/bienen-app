import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

class VermehrungFehler implements Exception {
  final String code;
  final String message;
  const VermehrungFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class VermehrungGateway {
  Future<List<VermehrungsEreignis>> alle();
  Future<void> speichern(VermehrungsEreignis e); // insert wenn id leer, sonst update
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId);
  Future<void> loeschen(String id);
}
