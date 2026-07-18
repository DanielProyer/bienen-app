import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';

void main() {
  test('Sammelfütterung A+B invalidiert BEIDE Volk-Family-Instanzen', () async {
    final fake = FakeFuetterungGateway();
    final container = ProviderContainer(overrides: [
      fuetterungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(fuetterungenFuerVolkProvider('v1').future)).length, 0);
    expect((await container.read(fuetterungenFuerVolkProvider('v2').future)).length, 0);

    final n = await container.read(fuetterungAktionenProvider).erfassen(
          volkIds: ['v1', 'v2'], durchgefuehrtAm: DateTime(2026, 8, 1), zweck: 'auffuetterung',
          futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: 5);
    expect(n, 2);

    expect((await container.read(fuetterungenFuerVolkProvider('v1').future)).length, 1);
    expect((await container.read(fuetterungenFuerVolkProvider('v2').future)).length, 1);
  });
}
