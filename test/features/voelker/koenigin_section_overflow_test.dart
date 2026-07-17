import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
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
        overrides: [darfSchreibenProvider.overrideWithValue(true)],
        child: const MaterialApp(
          home: Scaffold(
            body: KoeniginSection(volk: Volk(id: 'v1', name: 'Neu')),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Anlegen'), findsOneWidget);
    expect(find.text('Umweiseln'), findsOneWidget);
  });
}
