import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';

void main() {
  test('organische Saeuren + Thymol + Kombi = bio-konform', () {
    for (final w in ['ameisensaeure', 'oxalsaeure', 'milchsaeure', 'thymol', 'kombi_os_as']) {
      expect(bioKonformitaet(w, 'traeufeln'), BioBewertung.konform, reason: w);
    }
  });
  test('sonstige = Warnung', () {
    expect(bioKonformitaet('sonstige', 'traeufeln'), BioBewertung.warnung);
  });
  test('Biotechnik/Waerme = konform unabhaengig vom Wirkstoff', () {
    expect(bioKonformitaet('sonstige', 'biotechnik'), BioBewertung.konform);
    expect(bioKonformitaet('sonstige', 'waermebehandlung'), BioBewertung.konform);
  });
}
