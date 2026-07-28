import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/shared/widgets/bild_vollbild.dart';

/// Ein 1x1-PNG — reicht, um einen ImageProvider zu bedienen, ohne Assets
/// oder Netzwerk zu brauchen.
final _einPixel = MemoryImage(Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]));

/// Baut eine Seite mit einem Knopf, der die Vollbild-Ansicht öffnet.
Widget _seite({String? beschriftung, List<Widget> aktionen = const []}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => zeigeBildGross(context,
              bild: _einPixel, beschriftung: beschriftung, aktionen: aktionen),
          child: const Text('öffnen'),
        ),
      ),
    ),
  );
}

void main() {
  group('zeigeBildGross', () {
    testWidgets('öffnet eine zoombare Ansicht mit Schliessen-Knopf',
        (tester) async {
      await tester.pumpWidget(_seite());
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();

      // Ohne InteractiveViewer gäbe es kein Zoom — genau darum geht es.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Schliessen'), findsOneWidget);
    });

    testWidgets('zeigt die Beschriftung, wenn eine da ist', (tester) async {
      await tester.pumpWidget(_seite(beschriftung: 'Jahresraster der Varroa'));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();

      expect(find.text('Jahresraster der Varroa'), findsOneWidget);
    });

    testWidgets('leere Beschriftung erzeugt keine leere Zeile',
        (tester) async {
      await tester.pumpWidget(_seite(beschriftung: '   '));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();

      expect(find.text('   '), findsNothing);
    });

    testWidgets('zusätzliche Aktionen erscheinen neben Schliessen',
        (tester) async {
      await tester.pumpWidget(_seite(aktionen: [
        TextButton(onPressed: () {}, child: const Text('Löschen')),
      ]));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();

      expect(find.text('Löschen'), findsOneWidget);
      expect(find.text('Schliessen'), findsOneWidget);
    });

    testWidgets('Schliessen schliesst die Ansicht', (tester) async {
      await tester.pumpWidget(_seite());
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schliessen'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });
}
