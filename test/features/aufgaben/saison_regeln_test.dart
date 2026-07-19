import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';

void main() {
  test('Katalog: 25 Regeln, Keys unique', () {
    expect(kSaisonRegeln.length, 25);
    expect(kSaisonRegeln.map((r) => r.key).toSet().length, 25);
  });

  test('Kategorien = DB-CHECK-Werte', () {
    const erlaubt = {'durchsicht', 'behandlung', 'fuetterung', 'schutz', 'werkstatt', 'verwaltung', 'sonstiges'};
    for (final r in kSaisonRegeln) {
      expect(erlaubt.contains(r.kategorie), isTrue, reason: r.key);
    }
  });

  test('Fenster valide: Datum konstruierbar, Start <= Ende, KEIN Jahreswechsel', () {
    for (final r in kSaisonRegeln) {
      final start = DateTime(2026, r.startMonat, r.startTag);
      final ende = DateTime(2026, r.endMonat, r.endTag);
      expect(start.month, r.startMonat, reason: '${r.key}: Tag ungültig (Monatsüberlauf)');
      expect(ende.month, r.endMonat, reason: '${r.key}: Tag ungültig (Monatsüberlauf)');
      expect(start.isBefore(ende) || start.isAtSameMomentAs(ende), isTrue,
          reason: '${r.key}: Fenster über Jahreswechsel verboten (Gotcha 11)');
    }
  });

  test('aktionRoute nur bekannte Werte', () {
    const routen = {null, 'durchsicht', 'behandlung', 'fuetterung', 'varroa'};
    for (final r in kSaisonRegeln) {
      expect(routen.contains(r.aktionRoute), isTrue, reason: r.key);
    }
  });

  test('Intervall-Regeln: schwarmkontrolle 7, drohnenschnitt 14', () {
    expect(kSaisonRegeln.firstWhere((r) => r.key == 'schwarmkontrolle').intervallTage, 7);
    expect(kSaisonRegeln.firstWhere((r) => r.key == 'drohnenschnitt').intervallTage, 14);
  });

  test('regelVon: Lookup + null bei unbekanntem Key', () {
    expect(regelVon('schwarmkontrolle')?.intervallTage, 7);
    expect(regelVon('gibts_nicht'), isNull);
    expect(regelVon(null), isNull);
  });

  test('Offset nur auf Frühjahrs-/Trachtregeln (9 Stück)', () {
    expect(kSaisonRegeln.where((r) => r.offsetAnwenden).length, 9);
  });
}
