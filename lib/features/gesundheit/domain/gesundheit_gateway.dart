import 'dart:typed_data';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

class GesundheitFehler implements Exception {
  final String code;
  final String message;
  const GesundheitFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class GesundheitGateway {
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId); // inkl. stornierte, absteigend
  Future<void> speichern(Gesundheitsereignis e); // insert wenn id leer, sonst update
  Future<void> stornieren(String id, String grund);
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes});
  Future<String> fotoSignedUrl(String pfad);
  Future<void> fotoEntfernen(List<String> pfade);
}
