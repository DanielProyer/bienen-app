import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

void main() {
  test('Sammelbehandlung A+B invalidiert BEIDE Volk-Family-Instanzen', () async {
    final fake = FakeBehandlungGateway();
    final container = ProviderContainer(overrides: [
      behandlungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    // Caches beider Voelker fuellen (beide leer).
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 0);
    expect((await container.read(behandlungenFuerVolkProvider('v2').future)).length, 0);

    // Sammelbehandlung ueber beide.
    final n = await container.read(behandlungAktionenProvider).erfassen(
          volkIds: ['v1', 'v2'], datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'ameisensaeure',
          anwendungsart: 'dispenser_verdunster', verantwortlichePerson: 'Dani',
          praeparat: 'FORMIVAR', mengeProVolk: 40, einheit: 'ml');
    expect(n, 2);

    // Beide Families muessen nach der Invalidierung neu laden und den Eintrag sehen.
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);
    expect((await container.read(behandlungenFuerVolkProvider('v2').future)).length, 1);
  });
}
