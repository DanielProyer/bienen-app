import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/projekt/domain/meilensteine.dart';

void main() {
  test('genau ein Meilenstein ist der nächste Schritt', () {
    expect(kProjektMeilensteine.where((m) => m.status == MeilensteinStatus.naechster).length, 1);
  });
  test('Reihenfolge: erst erledigt, dann nächster, dann offen (keine Rücksprünge)', () {
    var phase = 0; // 0=erledigt, 1=naechster, 2=offen
    for (final m in kProjektMeilensteine) {
      final p = switch (m.status) {
        MeilensteinStatus.erledigt => 0,
        MeilensteinStatus.naechster => 1,
        MeilensteinStatus.offen => 2,
      };
      expect(p >= phase, isTrue, reason: m.titel);
      phase = p;
    }
  });
}
