import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));
void main() {
  testWidgets('AppButton zeigt Label und ruft onPressed', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppButton(label: 'Speichern', onPressed: () => tapped = true)));
    expect(find.text('Speichern'), findsOneWidget);
    await t.tap(find.text('Speichern'));
    expect(tapped, isTrue);
  });
  testWidgets('AppButton busy sperrt onPressed', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppButton(label: 'X', busy: true, onPressed: () => tapped = true)));
    await t.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });
  testWidgets('AppCard rendert Kind', (t) async {
    await t.pumpWidget(_host(const AppCard(child: Text('Inhalt'))));
    expect(find.text('Inhalt'), findsOneWidget);
  });
}
