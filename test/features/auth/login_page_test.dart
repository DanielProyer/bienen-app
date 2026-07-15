import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/login_page.dart';

Widget _app(FakeAuthGateway fake) => ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: LoginPage()),
    );

void main() {
  testWidgets('zeigt E-Mail- und Passwort-Feld', (t) async {
    await t.pumpWidget(_app(FakeAuthGateway()));
    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.byKey(const Key('login_passwort')), findsOneWidget);
    expect(find.byKey(const Key('login_absenden')), findsOneWidget);
  });

  testWidgets('leere Felder -> Validierungsfehler, kein Gateway-Aufruf',
      (t) async {
    final fake = FakeAuthGateway(
        ergebnis: const Angemeldet(FakeAuthGateway.beispielSession));
    await t.pumpWidget(_app(fake));
    await t.tap(find.byKey(const Key('login_absenden')));
    await t.pumpAndSettle();
    expect(find.text('Bitte gueltige E-Mail eingeben'), findsOneWidget);
    expect(find.text('Bitte Passwort eingeben'), findsOneWidget);
  });

  testWidgets('falsches Passwort -> Klartext-Fehler sichtbar', (t) async {
    final fake = FakeAuthGateway()
      ..wirftBeiSignIn = const AuthFehler('E-Mail oder Passwort stimmt nicht.',
          code: 'invalid_credentials');
    await t.pumpWidget(_app(fake));
    await t.enterText(find.byKey(const Key('login_email')), 'a@b.ch');
    await t.enterText(find.byKey(const Key('login_passwort')), 'falsch');
    await t.tap(find.byKey(const Key('login_absenden')));
    await t.pumpAndSettle();
    expect(find.text('E-Mail oder Passwort stimmt nicht.'), findsOneWidget);
  });
}
