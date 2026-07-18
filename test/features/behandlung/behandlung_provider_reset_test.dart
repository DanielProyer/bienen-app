import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

void main() {
  test('signOut invalidiert Behandlungs- UND Kontrollen-Cache (kein Stale nach Mandantenwechsel)',
      () async {
    final fake = FakeBehandlungGateway();
    await fake.behandlungErfassen(
        volkIds: ['v1'], datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'ameisensaeure',
        anwendungsart: 'dispenser_verdunster', verantwortlichePerson: 'A', praeparat: 'FORMIVAR',
        mengeProVolk: 40, einheit: 'ml');
    await fake.kontrolleSpeichern(VarroaKontrolle(
        id: '', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 8, 1),
        methode: 'gemuell', milbenGesamt: 9, messdauerTage: 3));

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      behandlungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    // Caches fuellen: Betrieb A sieht eine (nicht stornierte) Behandlung + eine Kontrolle.
    final b0 = (await container.read(behandlungenFuerVolkProvider('v1').future)).single;
    final k0 = await container.read(kontrollenFuerVolkProvider('v1').future);
    expect(b0.isStorniert, isFalse);
    expect(k0.length, 1);

    // Backend-Zustand aendert sich (simuliert Mandantenwechsel): Behandlung storniert, Kontrolle geloescht.
    await fake.behandlungStornieren(b0.id, 'weg');
    await fake.kontrolleLoeschen(k0.single.id);

    // Ohne Invalidierung zeigen die Family-Provider weiterhin den ALTEN Cache.
    expect(container.read(behandlungenFuerVolkProvider('v1')).valueOrNull?.single.isStorniert, isFalse);
    expect(container.read(kontrollenFuerVolkProvider('v1')).valueOrNull?.length, 1);

    // signOut() ruft _datenNeuLaden() -> MUSS behandlungenFuerVolkProvider UND kontrollenFuerVolkProvider invalidieren.
    await container.read(authControllerProvider.notifier).signOut();

    expect(
      (await container.read(behandlungenFuerVolkProvider('v1').future)).single.isStorniert,
      isTrue,
      reason: 'behandlungenFuerVolkProvider nach signOut nicht invalidiert (Stale-Cache)',
    );
    expect(
      (await container.read(kontrollenFuerVolkProvider('v1').future)).length,
      0,
      reason: 'kontrollenFuerVolkProvider nach signOut nicht invalidiert (Stale-Cache)',
    );
  });
}
