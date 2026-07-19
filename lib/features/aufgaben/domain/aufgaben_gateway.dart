import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

class AufgabenFehler implements Exception {
  final String code;
  final String message;
  const AufgabenFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class AufgabenGateway {
  Future<List<Aufgabe>> alle(); // ganzer Betrieb, faellig_am aufsteigend
  Future<void> speichern(Aufgabe a); // insert wenn id leer, sonst update
  /// Vorschlag annehmen/überspringen: mehrere Zeilen; Dedup-Konflikte (23505) still ignorieren.
  Future<void> speichernBatch(List<Aufgabe> aufgaben);
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm});
  Future<void> loeschen(String id);
}
