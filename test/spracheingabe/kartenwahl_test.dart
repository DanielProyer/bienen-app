import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/kartenwahl.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

SprachKarte _k(String text) =>
    SprachKarte(id: text, art: KartenArt.wort, sollText: text);

void main() {
  test('ohne Karten kommt nichts zurück', () {
    expect(naechsteKarte(karten: const [], bilanz: const {}), isNull);
  });

  test('eine noch nie geübte Karte hat Vorrang vor einer gelungenen', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {'Varroa': Kartenbilanz(versuche: 3, treffer: 3)},
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('unter geübten Karten kommt die mit der schlechteren Quote zuerst', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 4, treffer: 4),
        'Weiselzellen': Kartenbilanz(versuche: 4, treffer: 1),
      },
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('bei gleicher Quote kommt die seltener geübte zuerst', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 8, treffer: 4),
        'Weiselzellen': Kartenbilanz(versuche: 2, treffer: 1),
      },
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('die zuletzt gesprochene Karte kommt nicht sofort noch einmal', () {
    // Sonst haengt man bei einem hartnaeckigen Wort fest und uebt nichts sonst.
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 1, treffer: 0),
        'Weiselzellen': Kartenbilanz(versuche: 1, treffer: 1),
      },
      zuletzt: 'Varroa',
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('bei nur einer Karte wird sie auch dann gewählt, wenn sie zuletzt dran war', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa')],
      bilanz: const {},
      zuletzt: 'Varroa',
    );
    expect(gewaehlt!.sollText, 'Varroa');
  });
}
