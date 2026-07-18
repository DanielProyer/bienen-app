import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';

void main() {
  test('signOut invalidiert den Gesundheits-Cache', () async {
    final fake = FakeGesundheitGateway();
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb'));
    final c = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      gesundheitGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final e0 = (await c.read(gesundheitFuerVolkProvider('v1').future)).single;
    expect(e0.isStorniert, isFalse);
    await fake.stornieren(e0.id, 'weg');
    expect(c.read(gesundheitFuerVolkProvider('v1')).valueOrNull?.single.isStorniert, isFalse); // stale

    await c.read(authControllerProvider.notifier).signOut();
    expect((await c.read(gesundheitFuerVolkProvider('v1').future)).single.isStorniert, isTrue,
        reason: 'gesundheitFuerVolkProvider nach signOut nicht invalidiert');
  });
}
