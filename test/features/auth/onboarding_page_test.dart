import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/einladung_code_page.dart';
import 'package:bienen_app/features/auth/presentation/onboarding_page.dart';

Widget _app(FakeAuthGateway fake, Widget home) => ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(fake)],
      child: MaterialApp(home: home),
    );

void main() {
  group('OnboardingPage', () {
    testWidgets('gruendet den Betrieb mit dem eingegebenen Namen', (t) async {
      final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
      await t.pumpWidget(_app(fake, const OnboardingPage()));
      await t.enterText(find.byKey(const Key('onb_name')), 'Imkerei Arosa');
      await t.tap(find.byKey(const Key('onb_absenden')));
      await t.pumpAndSettle();
      expect(fake.letzterGruendungsName, 'Imkerei Arosa');
    });

    testWidgets('leerer Name -> Validierungsfehler, kein Aufruf', (t) async {
      final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
      await t.pumpWidget(_app(fake, const OnboardingPage()));
      await t.tap(find.byKey(const Key('onb_absenden')));
      await t.pumpAndSettle();
      expect(fake.letzterGruendungsName, isNull);
      expect(find.text('Bitte Namen eingeben'), findsOneWidget);
    });

    testWidgets('BA003 (bereits Mitglied) -> Klartext-Fehler', (t) async {
      final fake = FakeAuthGateway(ergebnis: const OhneBetrieb())
        ..wirftBeiGruenden = const AuthFehler(
            'Du gehoerst bereits zu einem Betrieb.',
            code: 'BA003');
      await t.pumpWidget(_app(fake, const OnboardingPage()));
      await t.enterText(find.byKey(const Key('onb_name')), 'X');
      await t.tap(find.byKey(const Key('onb_absenden')));
      await t.pumpAndSettle();
      expect(find.text('Du gehoerst bereits zu einem Betrieb.'), findsOneWidget);
    });
  });

  group('EinladungCodePage', () {
    testWidgets('loest den Code ein', (t) async {
      final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
      await t.pumpWidget(_app(fake, const EinladungCodePage()));
      await t.enterText(find.byKey(const Key('einl_code')), 'ABCD-EFGH-JKMN');
      await t.tap(find.byKey(const Key('einl_absenden')));
      await t.pumpAndSettle();
      expect(fake.letzterCode, 'ABCD-EFGH-JKMN');
    });

    testWidgets('BA007 (ungueltig/abgelaufen) -> Klartext-Fehler', (t) async {
      final fake = FakeAuthGateway(ergebnis: const OhneBetrieb())
        ..wirftBeiEinladung = const AuthFehler(
            'Einladungs-Code ungueltig oder abgelaufen.',
            code: 'BA007');
      await t.pumpWidget(_app(fake, const EinladungCodePage()));
      await t.enterText(find.byKey(const Key('einl_code')), 'XXXX-XXXX-XXXX');
      await t.tap(find.byKey(const Key('einl_absenden')));
      await t.pumpAndSettle();
      expect(find.text('Einladungs-Code ungueltig oder abgelaufen.'),
          findsOneWidget);
    });
  });
}
