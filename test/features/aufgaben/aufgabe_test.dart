import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('fromJson/toInsertJson Roundtrip inkl. Regel-Feldern', () {
    final j = {
      'id': 'a1', 'titel': 'Startfütterung', 'beschreibung': null,
      'kategorie': 'fuetterung', 'faellig_am': '2026-07-31',
      'prioritaet': 'hoch', 'status': 'offen', 'erledigt_am': null,
      'volk_id': 'v1', 'standort_id': null,
      'quelle': 'regel', 'regel_key': 'startfuetterung', 'saison_jahr': 2026,
    };
    final a = Aufgabe.fromJson(j);
    expect(a.faelligAm, DateTime(2026, 7, 31));
    expect(a.istOffen, isTrue);
    final ins = a.toInsertJson();
    expect(ins['faellig_am'], '2026-07-31');
    expect(ins['regel_key'], 'startfuetterung');
    expect(ins['saison_jahr'], 2026);
    expect(ins.containsKey('id'), isFalse);
    expect(ins.containsKey('erledigt_am'), isFalse); // wird nur via setzeStatus gesetzt
  });

  test('erledigt: istOffen false, erledigtAm geparst', () {
    final a = Aufgabe.fromJson({
      'id': 'a2', 'titel': 'X', 'kategorie': 'sonstiges', 'faellig_am': '2026-01-01',
      'status': 'erledigt', 'erledigt_am': '2026-01-02T10:00:00Z', 'quelle': 'manuell',
    });
    expect(a.istOffen, isFalse);
    expect(a.erledigtAm, isNotNull);
  });
}
