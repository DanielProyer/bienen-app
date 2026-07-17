import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/data/fake_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

void main() {
  test(
      'signOut invalidiert den Durchsichts-Cache (kein Stale-Cache nach Mandantenwechsel)',
      () async {
    final fake = FakeDurchsichtGateway();
    await fake.speichern(
        Durchsicht(id: 'd1', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 5, 1)));

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      durchsichtGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    // Cache fuellen: Betrieb A sieht d1.
    final erste = await container.read(durchsichtenFuerVolkProvider('v1').future);
    expect(erste.map((d) => d.id), ['d1']);

    // Backend-Zustand aendert sich (simuliert Mandantenwechsel): d1 weg, d2 da.
    await fake.loeschen(erste.first);
    await fake.speichern(
        Durchsicht(id: 'd2', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 6, 1)));

    // Ohne Invalidierung zeigt der AsyncNotifier weiterhin den alten Cache (d1).
    expect(
      container.read(durchsichtenFuerVolkProvider('v1')).valueOrNull?.map((d) => d.id),
      ['d1'],
    );

    // signOut() ruft _datenNeuLaden() auf, das u.a. durchsichtenFuerVolkProvider invalidieren muss.
    await container.read(authControllerProvider.notifier).signOut();

    final neu = await container.read(durchsichtenFuerVolkProvider('v1').future);
    expect(
      neu.map((d) => d.id),
      ['d2'],
      reason: 'nach signOut() darf kein Stale-Cache mehr sichtbar sein',
    );
  });
}
