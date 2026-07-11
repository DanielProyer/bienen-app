import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

void main() {
  test('fromJson maps snake_case DB keys', () {
    final step = ConstructionStep.fromJson({
      'step_key': 'nivellieren',
      'is_done': true,
      'note': 'ok',
      'photo_url': 'https://x/y.jpg',
      'photo_taken_at': '2026-07-11T10:00:00.000Z',
      'sort_order': 5,
    });
    expect(step.stepKey, 'nivellieren');
    expect(step.isDone, true);
    expect(step.note, 'ok');
    expect(step.sortOrder, 5);
    expect(step.photoTakenAt!.toUtc().hour, 10);
  });

  test('toJson round-trips through fromJson', () {
    const original = ConstructionStep(stepKey: 'pfosten', sortOrder: 3);
    final restored = ConstructionStep.fromJson(original.toJson());
    expect(restored.stepKey, 'pfosten');
    expect(restored.isDone, false);
    expect(restored.photoUrl, isNull);
    expect(restored.sortOrder, 3);
  });

  test('copyWith overrides only given fields', () {
    const s = ConstructionStep(stepKey: 'pfosten');
    final done = s.copyWith(isDone: true, note: 'fertig');
    expect(done.isDone, true);
    expect(done.note, 'fertig');
    expect(done.stepKey, 'pfosten');
  });
}
