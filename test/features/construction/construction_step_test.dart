import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

void main() {
  test('fromJson maps snake_case DB keys', () {
    final step = ConstructionStep.fromJson({
      'id': 'abc',
      'phase': 'bau',
      'foto_code': 'F06',
      'title': 'Pfosten im U-FIX',
      'soll': 'Pfosten fest',
      'sort_order': 6,
      'is_done': true,
      'note': 'ok',
      'photo_url': 'https://x/y.jpg',
      'photo_taken_at': '2026-07-11T10:00:00.000Z',
    });
    expect(step.id, 'abc');
    expect(step.fotoCode, 'F06');
    expect(step.isDone, true);
    expect(step.photoTakenAt!.toUtc().hour, 10);
  });

  test('toJson round-trips through fromJson', () {
    const original = ConstructionStep(
        id: '1', phase: 'bau', fotoCode: 'F02', title: 'Balken', sortOrder: 2);
    final restored = ConstructionStep.fromJson(original.toJson());
    expect(restored.id, '1');
    expect(restored.fotoCode, 'F02');
    expect(restored.isDone, false);
    expect(restored.photoUrl, isNull);
  });

  test('copyWith overrides only given fields', () {
    const s = ConstructionStep(
        id: '1', phase: 'bau', fotoCode: 'F02', title: 'Balken');
    final done = s.copyWith(isDone: true, note: 'fertig');
    expect(done.isDone, true);
    expect(done.note, 'fertig');
    expect(done.title, 'Balken');
  });
}
