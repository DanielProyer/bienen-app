import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';

ProviderContainer _container(FakeAuthGateway fake) {
  final c = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(fake)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('Start ohne Session -> abgemeldet', () async {
    final c = _container(FakeAuthGateway(ergebnis: const KeineSession()));
    await c.read(authControllerProvider.notifier).laden();
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });

  test('Session ohne Betrieb -> ohneBetrieb', () async {
    final c = _container(FakeAuthGateway(ergebnis: const OhneBetrieb()));
    await c.read(authControllerProvider.notifier).laden();
    expect(c.read(authControllerProvider).status, AuthStatus.ohneBetrieb);
  });

  test('Session mit Betrieb -> angemeldet + Claims', () async {
    final c = _container(FakeAuthGateway(
        ergebnis: const Angemeldet(FakeAuthGateway.beispielSession)));
    await c.read(authControllerProvider.notifier).laden();
    final st = c.read(authControllerProvider);
    expect(st.status, AuthStatus.angemeldet);
    expect(c.read(currentBetriebIdProvider), 'b1');
    expect(c.read(darfSchreibenProvider), isTrue);
  });

  test('betriebGruenden ruft refreshSession (frischer Claim) und meldet an',
      () async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c
        .read(authControllerProvider.notifier)
        .betriebGruenden('Imkerei Arosa');
    expect(fake.letzterGruendungsName, 'Imkerei Arosa');
    expect(fake.refreshAufrufe, greaterThanOrEqualTo(1),
        reason: 'refreshSession noetig fuer betrieb_id-Claim');
    expect(c.read(authControllerProvider).status, AuthStatus.angemeldet);
  });

  test('einladungAnnehmen refresht ebenfalls und meldet an', () async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c
        .read(authControllerProvider.notifier)
        .einladungAnnehmen('ABCD-EFGH-JKMN');
    expect(fake.letzterCode, 'ABCD-EFGH-JKMN');
    expect(fake.refreshAufrufe, greaterThanOrEqualTo(1));
    expect(c.read(authControllerProvider).status, AuthStatus.angemeldet);
  });

  test('signOut -> abgemeldet', () async {
    final fake = FakeAuthGateway(
        ergebnis: const Angemeldet(FakeAuthGateway.beispielSession));
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c.read(authControllerProvider.notifier).signOut();
    expect(fake.signOutAufrufe, 1);
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });

  test('signIn-Fehler wird durchgereicht, Status bleibt abgemeldet', () async {
    final fake = FakeAuthGateway(ergebnis: const KeineSession())
      ..wirftBeiSignIn = const AuthFehler('E-Mail oder Passwort stimmt nicht.',
          code: 'invalid_credentials');
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    // expectLater (nicht expect(() => ...)): der Fehler kommt ASYNCHRON aus dem
    // Future — ein synchroner throwsA-Match wuerde ihn verpassen.
    await expectLater(
      c.read(authControllerProvider.notifier).signIn('a@b.ch', 'x'),
      throwsA(isA<AuthFehler>()),
    );
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });
}
