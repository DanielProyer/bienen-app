import 'dart:typed_data';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

class DurchsichtFehler implements Exception {
  final String code;
  final String message;
  const DurchsichtFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class DurchsichtGateway {
  Future<List<Durchsicht>> fuerVolk(String volkId);          // absteigend nach Datum
  Future<List<Durchsicht>> letzteJeVolk();                   // aus v_letzte_durchsichten
  Future<void> speichern(Durchsicht d);                      // insert wenn id leer, sonst update
  Future<void> loeschen(Durchsicht d);                       // entfernt auch die Fotos
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}); // -> Pfad
  Future<String> fotoSignedUrl(String pfad);
  Future<void> fotoEntfernen(List<String> pfade);
}
