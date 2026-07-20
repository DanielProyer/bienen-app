import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

void main() {
  test('Fuetterung Roundtrip inkl. Storno-Felder', () {
    final f = Fuetterung.fromJson({
      'id': 'f1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-08-01', 'zweck': 'auffuetterung',
      'futterart': 'invertsirup', 'bio_zertifiziert': true, 'menge_pro_volk_kg': 5,
      'material_id': null, 'verantwortliche_person': 'Dani',
      'is_storniert': true, 'storno_grund': 'Tippfehler', 'storno_am': '2026-08-02', 'notiz': null,
    });
    expect(f.zweck, 'auffuetterung');
    expect(f.mengeProVolkKg, 5);
    expect(f.bioZertifiziert, isTrue);
    expect(f.isStorniert, isTrue);
    expect(f.stornoGrund, 'Tippfehler');
  });
}
