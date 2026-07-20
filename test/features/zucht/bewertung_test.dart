import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';

VolkBewertung _b({int s = 3, int w = 3, int schwarm = 3, int brut = 3, int staerke = 3, int g = 3, DateTime? am}) =>
    VolkBewertung(id: 'x', volkId: 'v1', bewertetAm: am ?? DateTime(2026, 6, 1),
        sanftmut: s, wabensitz: w, schwarmtraegheit: schwarm, brutbild: brut, volksstaerke: staerke, gesundheit: g);

void main() {
  test('Katalog-Invarianten: genau 6 Achsen, Keys eindeutig, je 4 Anker', () {
    expect(kBewertungsAchsen.length, 6);
    final keys = kBewertungsAchsen.map((a) => a.key).toList();
    expect(keys.toSet().length, 6);
    expect(keys.toSet(), {'sanftmut', 'wabensitz', 'schwarmtraegheit', 'brutbild', 'volksstaerke', 'gesundheit'});
    for (final a in kBewertungsAchsen) {
      expect(a.anker.length, 4, reason: a.key);
    }
  });

  test('wertFuer mappt alle 6 Keys', () {
    final b = _b(s: 1, w: 2, schwarm: 3, brut: 4, staerke: 1, g: 2);
    expect(b.wertFuer('sanftmut'), 1);
    expect(b.wertFuer('brutbild'), 4);
    expect(b.wertFuer('gesundheit'), 2);
    expect(() => b.wertFuer('gibtsnicht'), throwsArgumentError);
  });

  test('aggregiereSaison: Ø je Achse, MINIMUM für schwarmtraegheit, Gesamtnote = Ø der 6 rohen Aggregate', () {
    // schwarm: [4,4,1] -> Min 1; sanftmut [2,4,3] -> Ø 3.0
    final bs = [
      _b(s: 2, w: 3, schwarm: 4, brut: 3, staerke: 3, g: 3),
      _b(s: 4, w: 3, schwarm: 4, brut: 3, staerke: 3, g: 3),
      _b(s: 3, w: 3, schwarm: 1, brut: 3, staerke: 3, g: 3),
    ];
    final agg = aggregiereSaison(bs)!;
    expect(agg.achsen['schwarmtraegheit'], 1.0);      // Minimum
    expect(agg.achsen['sanftmut'], closeTo(3.0, 1e-9)); // (2+4+3)/3
    expect(agg.achsen['wabensitz'], 3.0);
    // Gesamtnote = Ø(3.0, 3.0, 1.0, 3.0, 3.0, 3.0) = 16/6
    expect(agg.gesamtnote, closeTo(16 / 6, 1e-9));
    expect(agg.anzahl, 3);
  });

  test('aggregiereSaison: 1 Bewertung = Werte; leer = null', () {
    expect(aggregiereSaison(const []), isNull);
    final agg = aggregiereSaison([_b(s: 4, schwarm: 2)])!;
    expect(agg.achsen['sanftmut'], 4.0);
    expect(agg.achsen['schwarmtraegheit'], 2.0);
  });

  test('fromJson/toInsertJson: ohne betrieb_id/id, koeniginId nullable', () {
    final b = VolkBewertung.fromJson({
      'id': 'a1', 'volk_id': 'v1', 'koenigin_id': null, 'bewertet_am': '2026-06-01',
      'sanftmut': 3, 'wabensitz': 3, 'schwarmtraegheit': 2, 'brutbild': 4, 'volksstaerke': 3, 'gesundheit': 4,
    });
    expect(b.koeniginId, isNull);
    expect(b.brutbild, 4);
    final j = b.toInsertJson();
    expect(j.containsKey('betrieb_id'), isFalse);
    expect(j.containsKey('id'), isFalse);
    expect(j['schwarmtraegheit'], 2);
    expect(j['bewertet_am'], '2026-06-01');
  });
}
