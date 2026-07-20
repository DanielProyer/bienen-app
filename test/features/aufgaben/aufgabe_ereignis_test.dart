import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('quelle=ereignis: ereignisId/schrittKey Roundtrip in toInsertJson', () {
    final a = Aufgabe(id: '', titel: 'x', kategorie: 'behandlung', faelligAm: DateTime(2026, 7, 1),
        quelle: 'ereignis', ereignisId: 'e1', schrittKey: 'zellen_brechen', volkId: 'v1');
    final j = a.toInsertJson();
    expect(j['ereignis_id'], 'e1');
    expect(j['schritt_key'], 'zellen_brechen');
    final b = Aufgabe.fromJson({...j, 'id': 'a1', 'prioritaet': 'normal', 'status': 'offen'});
    expect(b.ereignisId, 'e1');
    expect(b.schrittKey, 'zellen_brechen');
  });

  test('quelle=manuell: ereignis-Felder bleiben null', () {
    final a = Aufgabe(id: '', titel: 'x', kategorie: 'sonstiges', faelligAm: DateTime(2026, 7, 1));
    final j = a.toInsertJson();
    expect(j['ereignis_id'], isNull);
    expect(j['schritt_key'], isNull);
  });
}
