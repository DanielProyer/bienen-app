import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

class FakeBewertungGateway implements BewertungGateway {
  final _map = <String, VolkBewertung>{};
  int _seq = 0;
  @override
  Future<List<VolkBewertung>> alle() async => _map.values.toList();
  @override
  Future<void> speichern(VolkBewertung b) async {
    final id = b.id.isEmpty ? 'bw${++_seq}' : b.id;
    _map[id] = VolkBewertung(id: id, volkId: b.volkId, koeniginId: b.koeniginId, bewertetAm: b.bewertetAm,
        sanftmut: b.sanftmut, wabensitz: b.wabensitz, schwarmtraegheit: b.schwarmtraegheit,
        brutbild: b.brutbild, volksstaerke: b.volksstaerke, gesundheit: b.gesundheit, notiz: b.notiz);
  }
  @override
  Future<void> loeschen(String id) async => _map.remove(id);
}
