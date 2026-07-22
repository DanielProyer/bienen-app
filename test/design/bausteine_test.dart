import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/stat_tile.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

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
  testWidgets('SectionHeader zeigt Titel + trailing', (t) async {
    await t.pumpWidget(_host(const SectionHeader(titel: 'Heute', trailingText: '3 Aufgaben')));
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('3 Aufgaben'), findsOneWidget);
  });
  testWidgets('StatusPill nutzt Signal-Farbe', (t) async {
    await t.pumpWidget(_host(const StatusPill(label: 'überfällig', signal: BeeSignal.gefahr)));
    expect(find.text('überfällig'), findsOneWidget);
  });
  testWidgets('AppListTile: Titel/Untertitel + Tap', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppListTile(titel: 'Volk 1', untertitel: 'heute gesehen', onTap: () => tapped = true)));
    expect(find.text('Volk 1'), findsOneWidget);
    expect(find.text('heute gesehen'), findsOneWidget);
    await t.tap(find.text('Volk 1'));
    expect(tapped, isTrue);
  });
  testWidgets('StatTile: Label + Wert', (t) async {
    await t.pumpWidget(_host(const StatTile(label: 'Bisher', wert: 'CHF 640')));
    expect(find.text('Bisher'), findsOneWidget);
    expect(find.text('CHF 640'), findsOneWidget);
  });
}
