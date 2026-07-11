import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

ConstructionStep _s(String key, bool done) =>
    ConstructionStep(stepKey: key, isDone: done);

void main() {
  test('constructionProgress counts done; total = number of build steps', () {
    final steps = [_s('a', true), _s('b', false), _s('c', true)];
    final p = constructionProgress(steps);
    expect(p.done, 2);
    expect(p.total, kBuildSteps.length);
  });

  test('constructionProgress on empty list is 0 done', () {
    final p = constructionProgress(const []);
    expect(p.done, 0);
    expect(p.total, kBuildSteps.length);
  });

  test('there are 12 build steps with unique keys', () {
    expect(kBuildSteps.length, 12);
    final keys = kBuildSteps.map((s) => s.key).toSet();
    expect(keys.length, kBuildSteps.length);
  });
}
