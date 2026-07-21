import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  group('parseWabenKommandos', () {
    test('Mehr-Token in Reihenfolge', () {
      final r = parseWabenKommandos('Brut Pollen Königin nächste');
      expect(r.length, 4);
      expect((r[0] as InhaltAktion).key, 'brut');
      expect((r[0] as InhaltAktion).an, isTrue);
      expect((r[1] as InhaltAktion).key, 'pollen');
      expect((r[2] as FlagAktion).flag, 'koenigin');
      expect(r[3], isA<NaechsteAktion>());
    });
    test('Negation', () {
      final r = parseWabenKommandos('kein Brut ohne Königin');
      expect((r[0] as InhaltAktion).an, isFalse);
      expect((r[1] as FlagAktion).an, isFalse);
    });
    test('Navigation, Schied, Dialekt', () {
      expect(parseWabenKommandos('zurück').single, isA<ZurueckAktion>());
      expect(parseWabenKommandos('Trennschied').single, isA<SchiedAktion>());
      expect((parseWabenKommandos('Weisel').single as FlagAktion).flag, 'koenigin'); // Dialekt
    });
    test('unbekannt ignoriert', () => expect(parseWabenKommandos('das ist unklar'), isEmpty));
  });

  group('wendeWabenAktionen', () {
    test('setzt Inhalte + Flags auf aktive Wabe', () {
      final (ws, a) = wendeWabenAktionen(
          [const WabeBeobachtung(), const WabeBeobachtung()], 0,
          [const InhaltAktion('brut', true), const InhaltAktion('pollen', true), const FlagAktion('koenigin', true)]);
      expect(a, 0);
      expect(ws[0].inhalte, {'brut', 'pollen'});
      expect(ws[0].koenigin, isTrue);
    });
    test('Negation entfernt', () {
      final (ws, _) = wendeWabenAktionen([const WabeBeobachtung(inhalte: {'brut'})], 0, [const InhaltAktion('brut', false)]);
      expect(ws[0].inhalte, isEmpty);
    });
    test('nächste am Ende hängt neue Wabe an', () {
      final (ws, a) = wendeWabenAktionen([const WabeBeobachtung()], 0, [const NaechsteAktion()]);
      expect(ws.length, 2);
      expect(a, 1);
    });
    test('zurück am Anfang bleibt', () {
      final (_, a) = wendeWabenAktionen([const WabeBeobachtung()], 0, [const ZurueckAktion()]);
      expect(a, 0);
    });
    test('Schied trunkiert dahinter', () {
      final (ws, a) = wendeWabenAktionen(List.generate(3, (_) => const WabeBeobachtung()), 1, [const SchiedAktion()]);
      expect(ws.length, 2);
      expect(ws[1].schied, isTrue);
      expect(a, 1);
    });
    test('Inhalt auf Schied-Wabe ignoriert', () {
      final (ws, _) = wendeWabenAktionen([const WabeBeobachtung(schied: true)], 0, [const InhaltAktion('brut', true)]);
      expect(ws[0].schied, isTrue);
      expect(ws[0].inhalte, isEmpty);
    });
  });
}
