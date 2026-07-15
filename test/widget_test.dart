import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/main.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';

// Der alte Dashboard-Text-Check entfaellt bewusst: ohne Session ist das
// Dashboard nicht mehr erreichbar — genau das ist der Sinn des Auth-Gates.
// Supabase ist im Test nicht initialisiert, deshalb Gateway + Auth-Sync
// ueberschreiben.
Widget _app(FakeAuthGateway fake) => ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(fake),
        authSyncProvider.overrideWith((ref) {}),
      ],
      child: const BienenApp(),
    );

void main() {
  testWidgets('ohne Session -> Login', (tester) async {
    await tester.pumpWidget(_app(FakeAuthGateway(ergebnis: const KeineSession())));
    await tester.pumpAndSettle();
    expect(find.text('Anmelden'), findsWidgets);
  });

  testWidgets('Konto ohne Betrieb -> Onboarding', (tester) async {
    await tester.pumpWidget(_app(FakeAuthGateway(ergebnis: const OhneBetrieb())));
    await tester.pumpAndSettle();
    expect(find.text('Betrieb gruenden'), findsWidgets);
  });
}
