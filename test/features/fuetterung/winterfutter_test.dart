import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/winterfutter.dart';

Fuetterung _f(String zweck, DateTime am, num kg, {bool storniert = false}) => Fuetterung(
      id: 'x', volkId: 'v1', durchgefuehrtAm: am, zweck: zweck, futterart: 'invertsirup',
      bioZertifiziert: true, mengeProVolkKg: kg, isStorniert: storniert);

void main() {
  test('winterfutterKg summiert nur nicht-stornierte Auffütterung der Saison', () {
    final list = [
      _f('auffuetterung', DateTime(2026, 8, 1), 10),
      _f('auffuetterung', DateTime(2026, 9, 1), 8),
      _f('reizfuetterung', DateTime(2026, 8, 15), 1), // zaehlt nicht
      _f('notfuetterung', DateTime(2026, 8, 20), 2), // zaehlt nicht
      _f('auffuetterung', DateTime(2026, 8, 5), 5, storniert: true), // storniert
    ];
    // Stichtag im Herbst 2026 -> Saison ab 1.7.2026
    expect(winterfutterKg(list, stichtag: DateTime(2026, 9, 15)), 18.0);
  });

  test('Saison-Anker: im Januar zählt die Vorjahres-Herbst-Auffütterung noch (Balken != 0)', () {
    final list = [_f('auffuetterung', DateTime(2026, 9, 1), 12)];
    // Stichtag 15. Jan 2027, Monat < 7 -> Saisonstart 1.7.2026 -> Sept.-Eintrag zaehlt
    expect(winterfutterKg(list, stichtag: DateTime(2027, 1, 15)), 12.0);
  });

  test('vor dem Saisonstart liegende Auffütterung zählt nicht', () {
    final list = [_f('auffuetterung', DateTime(2026, 6, 30), 9)]; // vor 1.7.2026
    expect(winterfutterKg(list, stichtag: DateTime(2026, 9, 15)), 0.0);
  });

  test('winterfutterProzent null-/0-Ziel-sicher + Clamp', () {
    expect(winterfutterProzent(11, 22), closeTo(0.5, 0.001));
    expect(winterfutterProzent(30, 22), 1.0); // Clamp
    expect(winterfutterProzent(5, 0), 0.0);
  });
}
