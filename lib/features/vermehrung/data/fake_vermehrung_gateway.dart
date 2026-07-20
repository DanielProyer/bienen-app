import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';

class FakeVermehrungGateway implements VermehrungGateway {
  final _map = <String, VermehrungsEreignis>{};
  int _seq = 0;
  @override
  Future<List<VermehrungsEreignis>> alle() async => _map.values.toList();
  @override
  Future<void> speichern(VermehrungsEreignis e) async {
    final id = e.id.isEmpty ? 'ev${++_seq}' : e.id;
    _map[id] = VermehrungsEreignis(id: id, methode: e.methode, erstelltAm: e.erstelltAm,
        stammvolkId: e.stammvolkId, jungvolkId: e.jungvolkId, osBeiErstellung: e.osBeiErstellung, notiz: e.notiz);
  }
  @override
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    final e = _map[id];
    if (e == null) return;
    _map[id] = VermehrungsEreignis(id: e.id, methode: e.methode, erstelltAm: e.erstelltAm,
        stammvolkId: e.stammvolkId, jungvolkId: jungvolkId, osBeiErstellung: e.osBeiErstellung, notiz: e.notiz);
  }
  @override
  Future<void> loeschen(String id) async => _map.remove(id);
}
