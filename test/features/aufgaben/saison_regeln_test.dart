import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';

void main() {
  test('Katalog: 36 Regeln, Keys unique', () {
    expect(kSaisonRegeln.length, 36);
    expect(kSaisonRegeln.map((r) => r.key).toSet().length, 36);
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

  test('Offset nur auf Frühjahrs-/Trachtregeln (15 Stück)', () {
    // 9 Bestand + gemuelldiagnose_sommer (jetzt offset) + 5 neue offset-Regeln
    // (serbelvoelker_fruehjahr, varroakontrolle_fruehsommer, trachtluecke_notfuetterung,
    //  jungvoelker_bilden, koeniginnen_vermehren) = 15. Herbst-Regeln bleiben kalenderfix.
    expect(kSaisonRegeln.where((r) => r.offsetAnwenden).length, 15);
  });
}
