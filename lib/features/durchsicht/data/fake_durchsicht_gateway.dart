import 'dart:typed_data';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

class FakeDurchsichtGateway implements DurchsichtGateway {
  final _map = <String, Durchsicht>{};
  final entfernteFotos = <String>[];
  int _seq = 0;

  List<Durchsicht> get _alle =>
      _map.values.toList()..sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));

  @override
  Future<List<Durchsicht>> fuerVolk(String volkId) async =>
      _alle.where((d) => d.volkId == volkId).toList();

  @override
  Future<List<Durchsicht>> letzteJeVolk() async {
    final byVolk = <String, Durchsicht>{};
    for (final d in _alle) {
      byVolk.putIfAbsent(d.volkId, () => d); // _alle ist absteigend -> erstes = neuestes
    }
    return byVolk.values.toList();
  }

  @override
  Future<void> speichern(Durchsicht d) async {
    final id = d.id.isEmpty ? 'd${++_seq}' : d.id;
    _map[id] = Durchsicht(
      id: id, volkId: d.volkId, durchgefuehrtAm: d.durchgefuehrtAm, wetter: d.wetter,
      temperaturC: d.temperaturC, dauerMin: d.dauerMin, weiselzustand: d.weiselzustand,
      koeniginGesehen: d.koeniginGesehen, stifteGesehen: d.stifteGesehen,
      weiselzellen: d.weiselzellen, weiselzellenAnzahl: d.weiselzellenAnzahl,
      brutbild: d.brutbild, brutWaben: d.brutWaben, staerkeWabengassen: d.staerkeWabengassen,
      futterKg: d.futterKg, pollen: d.pollen, platz: d.platz, sanftmut: d.sanftmut,
      wabensitz: d.wabensitz, auffaelligkeiten: Durchsicht.gueltigeFlags(d.auffaelligkeiten),
      massnahmen: d.massnahmen, naechsteDurchsichtAm: d.naechsteDurchsichtAm,
      fotoUrls: d.fotoUrls, notiz: d.notiz,
    );
  }

  @override
  Future<void> loeschen(Durchsicht d) async {
    entfernteFotos.addAll(d.fotoUrls);
    _map.remove(d.id);
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) async =>
      '$betriebId/$gruppeId/foto_${++_seq}.jpg';

  @override
  Future<String> fotoSignedUrl(String pfad) async => 'https://signed.test/$pfad';

  @override
  Future<void> fotoEntfernen(List<String> pfade) async => entfernteFotos.addAll(pfade);
}
