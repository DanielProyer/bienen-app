import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/main.dart';

void main() {
  testWidgets('App starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BienenApp()));
    await tester.pumpAndSettle();
    expect(find.text('Projekt Bienen Arosa'), findsOneWidget);
  });
}
