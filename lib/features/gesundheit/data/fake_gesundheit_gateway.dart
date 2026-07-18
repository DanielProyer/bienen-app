import 'dart:typed_data';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheit_gateway.dart';

class FakeGesundheitGateway implements GesundheitGateway {
  final _map = <String, Gesundheitsereignis>{};
  final entfernteFotos = <String>[];
  int _seq = 0;

  List<Gesundheitsereignis> get _sort {
    final l = _map.values.toList();
    l.sort((a, b) => b.festgestelltAm.compareTo(a.festgestelltAm));
    return l;
  }

  @override
  Future<List<Gesundheitsereignis>> ereignisseFuerVolk(String volkId) async =>
      _sort.where((e) => e.volkId == volkId).toList();

  @override
  Future<void> speichern(Gesundheitsereignis e) async {
    final id = e.id.isEmpty ? 'g${++_seq}' : e.id;
    _map[id] = Gesundheitsereignis(
      id: id, volkId: e.volkId, festgestelltAm: e.festgestelltAm, krankheit: e.krankheit,
      schweregrad: e.schweregrad, status: e.status, gemeldetAm: e.gemeldetAm,
      laborEingesandt: e.laborEingesandt, fotoUrls: e.fotoUrls, massnahme: e.massnahme,
      verantwortlichePerson: e.verantwortlichePerson, notiz: e.notiz,
      isStorniert: e.isStorniert, stornoGrund: e.stornoGrund, stornoAm: e.stornoAm,
    );
  }

  @override
  Future<void> stornieren(String id, String grund) async {
    final e = _map[id];
    if (e == null) return;
    _map[id] = Gesundheitsereignis(
      id: e.id, volkId: e.volkId, festgestelltAm: e.festgestelltAm, krankheit: e.krankheit,
      schweregrad: e.schweregrad, status: e.status, gemeldetAm: e.gemeldetAm,
      laborEingesandt: e.laborEingesandt, fotoUrls: e.fotoUrls, massnahme: e.massnahme,
      verantwortlichePerson: e.verantwortlichePerson, notiz: e.notiz,
      isStorniert: true, stornoGrund: grund, stornoAm: e.festgestelltAm,
    );
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) async =>
      '$betriebId/$gruppeId/foto_${++_seq}.jpg';

  @override
  Future<String> fotoSignedUrl(String pfad) async => 'https://signed.test/$pfad';

  @override
  Future<void> fotoEntfernen(List<String> pfade) async => entfernteFotos.addAll(pfade);
}
