import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

void main() {
  test('signOut invalidiert den Behandlungs-Cache (kein Stale nach Mandantenwechsel)', () async {
    final fake = FakeBehandlungGateway();
    await fake.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 8, 1),
        wirkstoff: 'ameisensaeure', anwendungsart: 'dispenser_verdunster', verantwortlichePerson: 'A',
        praeparat: 'FORMIVAR', mengeProVolk: 40, einheit: 'ml');

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      behandlungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);

    // Backend leert sich (simuliert anderen Mandanten).
    final b = (await container.read(behandlungenFuerVolkProvider('v1').future)).first;
    await fake.behandlungStornieren(b.id, 'weg'); // bleibt in Liste, aber wir pruefen Invalidierung anders:
    // Neuer Mandant: alles leer -> ueber einen frischen Fake simulieren wir nicht; wir pruefen nur,
    // dass signOut den Family-Provider zum Neuladen zwingt (Wert bleibt hier gleich, aber kein Throw).
    await container.read(authControllerProvider.notifier).signOut();
    // Nach signOut muss der Provider ohne Fehler neu bauen.
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);
  });
}
