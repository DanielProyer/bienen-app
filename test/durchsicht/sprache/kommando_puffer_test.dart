import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/kommando_puffer.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  group('KommandoPuffer', () {
    test('der gemeldete Fehler: Feldwort und Wert in getrennten Stücken', () {
      // Genau das passiert beim Sprechen: Die Erkennung schliesst
      // „Temperatur" ab, bevor die Zahl gesprochen ist. Einzeln geparst
      // ergibt keines der beiden Stücke ein Kommando.
      final p = KommandoPuffer(SprachKontext.kontext);

      expect(p.fuettere('Temperatur'), isEmpty,
          reason: 'ein Feldwort allein ist noch kein Kommando');

      final k = p.fuettere('zwanzig Grad');
      expect(k, hasLength(1));
      expect(k.single, isA<ZahlKommando>()
          .having((z) => z.feld, 'feld', 'temperatur')
          .having((z) => z.wert, 'wert', 20));
    });

    test('ein vollständiges Stück wird sofort erkannt', () {
      final p = KommandoPuffer(SprachKontext.kontext);
      final k = p.fuettere('Temperatur 18 Grad');
      expect(k, hasLength(1));
      expect((k.single as ZahlKommando).wert, 18);
    });

    test('nach einem Treffer ist der Puffer leer — kein Nachhall', () {
      final p = KommandoPuffer(SprachKontext.kontext);
      p.fuettere('Temperatur 18');
      // „zwanzig" allein darf jetzt NICHT nochmal die Temperatur setzen.
      expect(p.fuettere('zwanzig'), isEmpty);
    });

    test('bei zwei Angaben im Satz greift die erste passende Regel', () {
      // parseKommando liefert bewusst höchstens ein Kommando je Satz; der
      // Puffer ändert daran nichts, er führt nur Stücke zusammen.
      final p = KommandoPuffer(SprachKontext.kontext);
      final k = p.fuettere('Temperatur 20 Grad');
      expect(k, hasLength(1));
      expect((k.single as ZahlKommando).feld, 'temperatur');
    });

    test('unverständliches sammelt sich nicht endlos an', () {
      final p = KommandoPuffer(SprachKontext.kontext, maxWoerter: 6);
      for (var i = 0; i < 10; i++) {
        p.fuettere('bla');
      }
      expect(p.offenerText.split(' ').length, lessThanOrEqualTo(6));
    });

    test('ein alter Rest verfälscht ein neues Kommando nicht', () {
      final p = KommandoPuffer(SprachKontext.kontext, maxWoerter: 4);
      p.fuettere('irgendwas unverständliches hier');
      final k = p.fuettere('Dauer 30');
      expect(k, hasLength(1));
      expect((k.single as ZahlKommando).feld, 'dauer');
    });

    test('leeren verwirft das aufgehobene Feldwort', () {
      final p = KommandoPuffer(SprachKontext.kontext);
      p.fuettere('Temperatur');
      expect(p.offenerText, 'Temperatur');

      p.leeren();
      expect(p.offenerText, isEmpty);

      // Ohne das aufgehobene „Temperatur" darf eine blosse Zahl nichts setzen.
      expect(p.fuettere('zwanzig'), isEmpty);
    });

    test('funktioniert auch im Kennzahlen-Kontext', () {
      final p = KommandoPuffer(SprachKontext.kennzahlen);
      expect(p.fuettere('Brutwaben'), isEmpty);
      final k = p.fuettere('sechs');
      expect(k, hasLength(1));
      expect((k.single as ZahlKommando).feld, 'brutwaben');
    });
  });
}
