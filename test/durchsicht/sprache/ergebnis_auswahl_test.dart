import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/ergebnis_auswahl.dart';

/// Kurzschreibweise für ein Ergebnis, wie es die Web Speech API liefert.
({String text, bool endgueltig}) e(String t, {bool fin = false}) =>
    (text: t, endgueltig: fin);

void main() {
  group('ErgebnisAuswahl', () {
    test('der gemeldete Fehler: „schönes Wetter" kommt genau einmal', () {
      final a = ErgebnisAuswahl();

      // „schönes" noch vorläufig
      var r = a.verarbeite([e('schönes')]);
      expect(r.neuerEndtext, isNull);
      expect(r.interim, 'schönes');

      // „schönes" wird endgültig
      r = a.verarbeite([e('schönes', fin: true)]);
      expect(r.neuerEndtext, 'schönes');

      // Der Browser schickt die ganze Liste erneut mit — darf nichts auslösen
      r = a.verarbeite([e('schönes', fin: true)]);
      expect(r.neuerEndtext, isNull,
          reason: 'unverändertes Endergebnis darf nicht erneut gemeldet werden');

      // „Wetter" kommt dazu, die Liste enthält weiterhin „schönes"
      r = a.verarbeite([e('schönes', fin: true), e('Wetter', fin: true)]);
      expect(r.neuerEndtext, 'Wetter');

      // Und nochmal dieselbe Liste
      r = a.verarbeite([e('schönes', fin: true), e('Wetter', fin: true)]);
      expect(r.neuerEndtext, isNull);
    });

    test('nach einem Neustart beginnt der Text von vorn — er darf nicht '
        'für schon geliefert gehalten werden', () {
      // Das war die Ursache dafür, dass beim zweiten Anlauf nur noch das
      // erste Wort ankam: Der neue Lauf liefert wieder Index 0.
      final a = ErgebnisAuswahl();
      a.verarbeite([e('schönes', fin: true)]);

      final r = a.verarbeite([e('Wetter', fin: true)]);
      expect(r.neuerEndtext, 'Wetter');
    });

    test('ein Satz, der im selben Eintrag wächst, meldet nur den Zuwachs', () {
      // Chrome verlängert oft denselben Eintrag, statt einen neuen anzufügen.
      final a = ErgebnisAuswahl();
      var r = a.verarbeite([e('das Volk', fin: true)]);
      expect(r.neuerEndtext, 'das Volk');

      r = a.verarbeite([e('das Volk ist ruhig', fin: true)]);
      expect(r.neuerEndtext, 'ist ruhig');
    });

    test('vorläufiger Text wird durchgereicht, aber nie als endgültig', () {
      final a = ErgebnisAuswahl();
      for (final t in ['tem', 'tempera', 'temperatur']) {
        final r = a.verarbeite([e(t)]);
        expect(r.interim, t);
        expect(r.neuerEndtext, isNull);
      }
    });

    test('endgültig und vorläufig gemischt', () {
      final a = ErgebnisAuswahl();
      final r =
          a.verarbeite([e('temperatur', fin: true), e('zwanzig')]);
      expect(r.neuerEndtext, 'temperatur');
      expect(r.interim, 'zwanzig');
    });

    test('leere und reine Leerzeichen-Ergebnisse lösen nichts aus', () {
      final a = ErgebnisAuswahl();
      final r = a.verarbeite([e('   ', fin: true), e('')]);
      expect(r.neuerEndtext, isNull);
      expect(r.interim, isEmpty);
    });

    test('zuruecksetzen beginnt eine frische Sitzung', () {
      final a = ErgebnisAuswahl();
      a.verarbeite([e('erster Satz', fin: true)]);
      a.zuruecksetzen();

      final r = a.verarbeite([e('erster Satz', fin: true)]);
      expect(r.neuerEndtext, 'erster Satz',
          reason: 'nach dem Zurücksetzen ist derselbe Text wieder neu');
    });

    test('führende Leerzeichen im Zuwachs werden abgeschnitten', () {
      final a = ErgebnisAuswahl();
      a.verarbeite([e('eins', fin: true)]);
      final r = a.verarbeite([e('eins  zwei', fin: true)]);
      expect(r.neuerEndtext, 'zwei');
    });
  });
}
