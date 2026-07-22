import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/koenigin_section.dart';

void main() {
  testWidgets('KoeniginSection weisellos+Schreibrechte kein Overflow bei 360dp',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          darfSchreibenProvider.overrideWithValue(true),
          voelkerGatewayProvider.overrideWithValue(FakeVoelkerGateway()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: KoeniginSection(volk: Volk(id: 'v1', name: 'Neu')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Anlegen'), findsOneWidget);
    // Ohne Königin ist es eine Erst-Zuordnung, keine Umweiselung. Der frühere
    // Text „Umweiseln" liess Daniel nicht erkennen, wie ein weiselloses Volk
    // seine erste Königin bekommt.
    expect(find.text('Zuordnen'), findsOneWidget);
    expect(find.text('Umweiseln'), findsNothing);
  });

  testWidgets('KoeniginSection mit Königin: Umweiseln statt Zuordnen, kein Anlegen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          darfSchreibenProvider.overrideWithValue(true),
          voelkerGatewayProvider.overrideWithValue(FakeVoelkerGateway()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: KoeniginSection(
              volk: Volk(
                id: 'v1',
                name: 'Mit Königin',
                koeniginId: 'k1',
                koenigin: Koenigin(id: 'k1', kennung: 'Liv', schlupfjahr: 2026),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Umweiseln'), findsOneWidget);
    expect(find.text('Zuordnen'), findsNothing);
    expect(find.text('Anlegen'), findsNothing,
        reason: 'bei vorhandener Königin gibt es nichts anzulegen');
    expect(find.textContaining('Liv'), findsOneWidget);
  });
}
