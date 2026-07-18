import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';

void main() {
  test('signOut invalidiert den Fütterungs-Cache (kein Stale nach Mandantenwechsel)', () async {
    final fake = FakeFuetterungGateway();
    await fake.fuetterungErfassen(volkIds: ['v1'], durchgefuehrtAm: DateTime(2026, 8, 1),
        zweck: 'auffuetterung', futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: 5);

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      fuetterungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final f0 = (await container.read(fuetterungenFuerVolkProvider('v1').future)).single;
    expect(f0.isStorniert, isFalse);

    // Backend aendert sich: Eintrag storniert.
    await fake.fuetterungStornieren(f0.id, 'weg');
    // Stale-Cache zeigt weiterhin nicht-storniert.
    expect(container.read(fuetterungenFuerVolkProvider('v1')).valueOrNull?.single.isStorniert, isFalse);

    // signOut -> _datenNeuLaden() muss fuetterungenFuerVolkProvider invalidieren.
    await container.read(authControllerProvider.notifier).signOut();
    expect(
      (await container.read(fuetterungenFuerVolkProvider('v1').future)).single.isStorniert,
      isTrue,
      reason: 'fuetterungenFuerVolkProvider nach signOut nicht invalidiert',
    );
  });
}
