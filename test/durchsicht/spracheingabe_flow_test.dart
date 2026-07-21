import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/fake_sprache_erkenner.dart';

void main() {
  test('Controller routet End-Transkript an aktives Mikro; Interim separat', () async {
    final fake = FakeSpracheErkenner();
    final c = ProviderContainer(overrides: [spracheErkennerProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    final ctrl = c.read(sprachControllerProvider.notifier);

    final empfangen = <String>[];
    await ctrl.starten('m1', empfangen.add);
    expect(c.read(sprachControllerProvider).aktivesMikro, 'm1');

    fake.sende('brutwaben fuenf', endgueltig: false);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(sprachControllerProvider).interim, 'brutwaben fuenf');
    expect(empfangen, isEmpty);

    fake.sende('brutwaben 5', endgueltig: true);
    await Future<void>.delayed(Duration.zero);
    expect(empfangen, ['brutwaben 5']);
    expect(c.read(sprachControllerProvider).interim, '');

    await ctrl.stoppen();
    expect(c.read(sprachControllerProvider).aktivesMikro, isNull);
  });
}
