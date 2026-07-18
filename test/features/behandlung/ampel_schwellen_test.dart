import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';

void main() {
  test('milbenProTag null-sicher (0/null Nenner)', () {
    expect(milbenProTag(10, 5), 2.0);
    expect(milbenProTag(10, 0), isNull);
    expect(milbenProTag(10, null), isNull);
    expect(milbenProTag(null, 5), isNull);
  });
  test('befallProzent null-sicher', () {
    expect(befallProzent(3, 300), closeTo(1.0, 0.001));
    expect(befallProzent(3, 0), isNull);
    expect(befallProzent(null, 300), isNull);
  });
  test('ampelGemuell Recherche-Anker Jul/Aug/Sep', () {
    expect(ampelGemuell(4, 7), Ampel.gruen);
    expect(ampelGemuell(8, 7), Ampel.gelb);
    expect(ampelGemuell(11, 7), Ampel.rot);
    expect(ampelGemuell(9, 8), Ampel.gruen);
    expect(ampelGemuell(20, 8), Ampel.gelb);
    expect(ampelGemuell(26, 8), Ampel.rot);
    expect(ampelGemuell(14, 9), Ampel.gruen);
    expect(ampelGemuell(26, 9), Ampel.rot);
  });
  test('ampelGemuell Nov-Apr = keinRichtwert; null = keinRichtwert', () {
    for (final m in [11, 12, 1, 2, 3, 4]) {
      expect(ampelGemuell(5, m), Ampel.keinRichtwert, reason: 'Monat $m');
    }
    expect(ampelGemuell(null, 8), Ampel.keinRichtwert);
  });
  test('ampelPuderzucker (%-Bänder)', () {
    expect(ampelPuderzucker(0.5), Ampel.gruen);
    expect(ampelPuderzucker(2), Ampel.gelb);
    expect(ampelPuderzucker(4), Ampel.rot);
    expect(ampelPuderzucker(null), Ampel.keinRichtwert);
  });
  test('ampelFuerKontrolle wählt die Skala nach Methode', () {
    expect(ampelFuerKontrolle(methode: 'gemuell', milbenGesamt: 44, messdauerTage: 4, monat: 8), Ampel.gelb); // 11/Tag
    expect(ampelFuerKontrolle(methode: 'puderzucker', milbenGesamt: 12, bienenProbe: 300, monat: 8), Ampel.rot); // 4% -> rot (Plan-Tippfehler korrigiert, siehe Task-Report)
  });
}
