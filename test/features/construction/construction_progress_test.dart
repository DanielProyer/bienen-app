import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

ConstructionStep _s(String id, bool done) =>
    ConstructionStep(id: id, phase: 'bau', fotoCode: 'F$id', title: 't', isDone: done);

void main() {
  test('constructionProgress counts done and total', () {
    final steps = [_s('1', true), _s('2', false), _s('3', true)];
    final p = constructionProgress(steps);
    expect(p.done, 2);
    expect(p.total, 3);
  });

  test('constructionProgress on empty list is 0/0', () {
    final p = constructionProgress(const []);
    expect(p.done, 0);
    expect(p.total, 0);
  });
}
