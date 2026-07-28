import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/ergebnis_auswahl.dart';

/// Kurzschreibweise für ein Ergebnis, wie es die Web Speech API liefert.
({String text, bool endgueltig}) e(String t, {bool fin = false}) =>
    (text: t, endgueltig: fin);

void main() {
  group('ErgebnisAuswahl', () {
    test('der gemeldete Fehler: „schönes Wetter" wird nicht vervielfacht', () {
      final auswahl = ErgebnisAuswahl();

      // 1) „schönes" ist noch vorläufig
      var raus = auswahl.auswaehlen(resultIndex: 0, ergebnisse: [e('schönes')]);
      expect(raus.map((r) => r.text), ['schönes']);
      expect(raus.single.endgueltig, isFalse);

      // 2) „schönes" wird endgültig — jetzt darf es genau einmal heraus
      raus = auswahl
          .auswaehlen(resultIndex: 0, ergebnisse: [e('schönes', fin: true)]);
      expect(raus.map((r) => r.text), ['schönes']);
      expect(raus.single.endgueltig, isTrue);

      // 3) Es folgt „Wetter". Der Browser schickt die GANZE Liste mit —
      //    inklusive des bereits gelieferten „schönes". Genau hier entstand
      //    das „schönes schönes schönes wetter".
      raus = auswahl.auswaehlen(
          resultIndex: 1,
          ergebnisse: [e('schönes', fin: true), e('Wetter')]);
      expect(raus.map((r) => r.text), ['Wetter'],
          reason: 'ein bereits geliefertes Endergebnis darf nicht erneut kommen');

      // 4) „Wetter" wird endgültig
      raus = auswahl.auswaehlen(
          resultIndex: 1,
          ergebnisse: [e('schönes', fin: true), e('Wetter', fin: true)]);
      expect(raus.map((r) => r.text), ['Wetter']);
      expect(raus.single.endgueltig, isTrue);
    });

    test('auch wenn der Browser resultIndex stur auf 0 lässt', () {
      // Manche Browser melden im Dauer-Modus immer 0. Der Schutz darf sich
      // deshalb nicht allein auf resultIndex verlassen.
      final auswahl = ErgebnisAuswahl();
      auswahl.auswaehlen(resultIndex: 0, ergebnisse: [e('eins', fin: true)]);

      final raus = auswahl.auswaehlen(
          resultIndex: 0,
          ergebnisse: [e('eins', fin: true), e('zwei', fin: true)]);
      expect(raus.map((r) => r.text), ['zwei']);
    });

    test('vorläufige Ergebnisse dürfen sich beliebig oft ändern', () {
      final auswahl = ErgebnisAuswahl();
      for (final t in ['sch', 'schön', 'schönes']) {
        final raus = auswahl.auswaehlen(resultIndex: 0, ergebnisse: [e(t)]);
        expect(raus.map((r) => r.text), [t]);
      }
    });

    test('nach einem Neustart beginnt die Zählung von vorn', () {
      // Der Dauer-Modus startet die Erkennung nach jeder Pause neu; das
      // results-Array fängt dann wieder bei 0 an. Ohne Rücksetzen bliebe der
      // erste Satz nach dem Neustart stumm.
      final auswahl = ErgebnisAuswahl();
      auswahl.auswaehlen(
          resultIndex: 0,
          ergebnisse: [e('erster Satz', fin: true), e('zweiter', fin: true)]);

      auswahl.zuruecksetzen();
      final raus = auswahl
          .auswaehlen(resultIndex: 0, ergebnisse: [e('neuer Satz', fin: true)]);
      expect(raus.map((r) => r.text), ['neuer Satz']);
    });

    test('leere Ergebnisse werden nicht durchgereicht', () {
      final auswahl = ErgebnisAuswahl();
      final raus = auswahl.auswaehlen(
          resultIndex: 0, ergebnisse: [e('   '), e('', fin: true)]);
      expect(raus, isEmpty);
    });

    test('resultIndex jenseits der Liste führt nicht zum Absturz', () {
      final auswahl = ErgebnisAuswahl();
      expect(
        () => auswahl.auswaehlen(resultIndex: 5, ergebnisse: [e('x')]),
        returnsNormally,
      );
    });
  });
}
