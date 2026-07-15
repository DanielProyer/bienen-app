import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

ConstructionStep _s(String key, bool done) =>
    ConstructionStep(stepKey: key, isDone: done);

void main() {
  group('progressFor', () {
    test('zaehlt nur ERLEDIGTE Schritte DES eigenen Bereichs', () {
      // Bienenstand- und Honigverarbeitungs-Schritte liegen in derselben Tabelle
      // und werden nur ueber den step_key getrennt (ab v1.7.1).
      final steps = [
        _s(kBuildSteps[0].key, true), // zaehlt
        _s(kBuildSteps[1].key, true), // zaehlt
        _s(kBuildSteps[2].key, false), // nicht erledigt -> zaehlt nicht
        _s(kHonigverarbeitungSteps[0].key, true), // anderer Bereich -> zaehlt nicht
        _s('unbekannter_key', true), // Fremdschluessel -> zaehlt nicht
      ];
      final p = progressFor(steps, kBuildSteps);
      expect(p.done, 2);
      expect(p.total, kBuildSteps.length);
    });

    test('trennt die Bereiche sauber (Gegenprobe Honigverarbeitung)', () {
      final steps = [
        _s(kBuildSteps[0].key, true),
        _s(kHonigverarbeitungSteps[0].key, true),
      ];
      final hv = progressFor(steps, kHonigverarbeitungSteps);
      expect(hv.done, 1);
      expect(hv.total, kHonigverarbeitungSteps.length);
    });

    test('leere Liste -> 0 erledigt, total bleibt die Bereichsgroesse', () {
      final p = progressFor(const [], kBuildSteps);
      expect(p.done, 0);
      expect(p.total, kBuildSteps.length);
    });
  });

  test('there are 12 build steps with unique keys', () {
    expect(kBuildSteps.length, 12);
    final keys = kBuildSteps.map((s) => s.key).toSet();
    expect(keys.length, kBuildSteps.length);
  });

  test('Honigverarbeitung hat 10 Schritte mit eindeutigen keys', () {
    expect(kHonigverarbeitungSteps.length, 10);
    final keys = kHonigverarbeitungSteps.map((s) => s.key).toSet();
    expect(keys.length, kHonigverarbeitungSteps.length);
  });

  test('Bienenstand- und Honigverarbeitungs-Keys ueberschneiden sich nicht', () {
    final a = kBuildSteps.map((s) => s.key).toSet();
    final b = kHonigverarbeitungSteps.map((s) => s.key).toSet();
    expect(a.intersection(b), isEmpty);
  });
}
