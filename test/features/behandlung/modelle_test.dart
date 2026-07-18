import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';

void main() {
  test('VarroaKontrolle Roundtrip', () {
    final k = VarroaKontrolle.fromJson({
      'id': 'k1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-08-01',
      'methode': 'gemuell', 'messdauer_tage': 3, 'milben_gesamt': 30, 'bienen_probe': null, 'notiz': 'x',
    });
    expect(k.methode, 'gemuell');
    expect(k.milbenGesamt, 30);
    final j = k.toInsertJson();
    expect(j['volk_id'], 'v1');
    expect(j['durchgefuehrt_am'], '2026-08-01');
    expect(j.containsKey('id'), isFalse);
  });
  test('Behandlung Roundtrip inkl. Storno-Felder', () {
    final b = Behandlung.fromJson({
      'id': 'b1', 'volk_id': 'v1', 'datum_beginn': '2026-08-02', 'datum_ende': null,
      'praeparat': 'FORMIVAR 60%', 'wirkstoff': 'ameisensaeure', 'menge_pro_volk': 40, 'einheit': 'ml',
      'konzentration': '60%', 'anwendungsart': 'dispenser_verdunster', 'indikation': 'Varroabekämpfung',
      'aussentemperatur_c': 22, 'wartefrist_tage': 0, 'charge': 'C1', 'verantwortliche_person': 'Dani',
      'material_id': null, 'is_storniert': true, 'storno_grund': 'Tippfehler', 'storno_am': '2026-08-03', 'notiz': null,
    });
    expect(b.wirkstoff, 'ameisensaeure');
    expect(b.isStorniert, isTrue);
    expect(b.stornoGrund, 'Tippfehler');
    expect(b.mengeProVolk, 40);
  });
}
