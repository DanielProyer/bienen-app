import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

void main() {
  test('EinstellungenNotifier.speichern ruft Gateway + invalidiert', () async {
    final gw = FakeVoelkerGateway();
    // currentBetriebIdProvider muss non-null sein, sonst returnt speichern früh
    // (AuthState.laden().betriebId == null im Test-Kontext).
    final c = ProviderContainer(overrides: [
      voelkerGatewayProvider.overrideWithValue(gw),
      currentBetriebIdProvider.overrideWithValue('b1'),
    ]);
    addTearDown(c.dispose);
    await c.read(betriebsEinstellungenProvider.future);
    const neu = BetriebsEinstellungen(saisonOffsetDefaultTage: 42, winterfutterZielKg: 24,
        anzahlErnten: 2, sommerbehandlungMethode: 'beide', vermehrungAktiv: true);
    await c.read(betriebsEinstellungenProvider.notifier).speichern(neu);
    final wieder = await c.read(betriebsEinstellungenProvider.future);
    expect(wieder.anzahlErnten, 2);
    expect(wieder.vermehrungAktiv, true);
  });
}
