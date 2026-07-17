import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

void main() {
  test('signOut invalidiert den Voelker-Cache (kein Stale-Cache nach Mandantenwechsel)',
      () async {
    final fakeVoelker = FakeVoelkerGateway();
    await fakeVoelker.volkSpeichern(const Volk(id: 'v1', name: 'Betrieb-A-Volk'));

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      voelkerGatewayProvider.overrideWithValue(fakeVoelker),
    ]);
    addTearDown(container.dispose);

    // Cache fuellen: Betrieb A sieht nur v1.
    final erste = await container.read(voelkerListProvider.future);
    expect(erste.map((v) => v.id), ['v1']);

    // Backend-Zustand aendert sich (simuliert Mandantenwechsel): v1 weg, v2 da.
    await fakeVoelker.volkLoeschen('v1');
    await fakeVoelker.volkSpeichern(const Volk(id: 'v2', name: 'Betrieb-B-Volk'));

    // Ohne Invalidierung zeigt der AsyncNotifier weiterhin den alten Cache (v1).
    expect(
      container.read(voelkerListProvider).valueOrNull?.map((v) => v.id),
      ['v1'],
    );

    // signOut() ruft _datenNeuLaden() auf, das u.a. voelkerListProvider invalidieren muss.
    await container.read(authControllerProvider.notifier).signOut();

    final neu = await container.read(voelkerListProvider.future);
    expect(
      neu.map((v) => v.id),
      ['v2'],
      reason: 'nach signOut() darf kein Stale-Cache mehr sichtbar sein',
    );
  });
}
