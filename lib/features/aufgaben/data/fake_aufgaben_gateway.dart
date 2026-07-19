import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';

class FakeAufgabenGateway implements AufgabenGateway {
  final List<Aufgabe> _rows = [];
  int _seq = 0;

  String _key(Aufgabe a) => '${a.regelKey}|${a.saisonJahr}|${a.volkId}|${a.faelligAm}';

  @override
  Future<List<Aufgabe>> alle() async =>
      List.of(_rows)..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));

  @override
  Future<void> speichern(Aufgabe a) async {
    if (a.id.isEmpty) {
      _rows.add(Aufgabe(
        id: 'f${++_seq}', titel: a.titel, beschreibung: a.beschreibung,
        kategorie: a.kategorie, faelligAm: a.faelligAm, prioritaet: a.prioritaet,
        status: a.status, volkId: a.volkId, standortId: a.standortId,
        quelle: a.quelle, regelKey: a.regelKey, saisonJahr: a.saisonJahr,
      ));
    } else {
      final i = _rows.indexWhere((x) => x.id == a.id);
      if (i >= 0) _rows[i] = a;
    }
  }

  @override
  Future<void> speichernBatch(List<Aufgabe> aufgaben) async {
    for (final a in aufgaben) {
      // Dedup wie der DB-Index: gleiche Regel-Zeile still überspringen.
      if (a.quelle == 'regel' &&
          _rows.any((x) => x.quelle == 'regel' && _key(x) == _key(a))) {
        continue;
      }
      await speichern(a);
    }
  }

  @override
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm}) async {
    final i = _rows.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final a = _rows[i];
    _rows[i] = Aufgabe(
      id: a.id, titel: a.titel, beschreibung: a.beschreibung, kategorie: a.kategorie,
      faelligAm: a.faelligAm, prioritaet: a.prioritaet, status: status,
      erledigtAm: erledigtAm, volkId: a.volkId, standortId: a.standortId,
      quelle: a.quelle, regelKey: a.regelKey, saisonJahr: a.saisonJahr,
    );
  }

  @override
  Future<void> loeschen(String id) async => _rows.removeWhere((x) => x.id == id);
}
