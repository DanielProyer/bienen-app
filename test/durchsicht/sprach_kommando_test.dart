import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  SprachKommando? p(String s, [SprachKontext k = SprachKontext.kennzahlen]) => parseKommando(s, k);

  test('Zahl-Kommandos', () {
    expect(p('Brutwaben 5'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'brutwaben').having((z) => z.wert, 'wert', 5));
    expect(p('Wabengassen acht'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'staerke').having((z) => z.wert, 'wert', 8));
    expect(p('Temperatur 22', SprachKontext.kontext), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'temperatur'));
  });
  test('bare Zahl ohne Feldwort → null', () => expect(p('fünf'), isNull));
  test('Enum-Kommandos → technischer Key', () {
    expect(p('Brutbild geschlossen'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'geschlossen'));
    expect(p('Platz zu gross'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'zu_gross'));
    expect(p('Weiselzustand drohnenbrütig', SprachKontext.kontext), isA<EnumKommando>().having((e) => e.wert, 'wert', 'drohnenbruetig'));
  });
  test('Bool + Negation + Mundart', () {
    expect((p('Königin ja') as BoolKommando).wert, isTrue);
    expect((p('keine Königin') as BoolKommando).wert, isFalse);
    expect((p('Chüngin') as BoolKommando).wert, isTrue); // Mundart-Alias
    expect((p('Stifte nein') as BoolKommando).wert, isFalse);
  });
  test('Anzahl Weiselzellen vor Enum Weiselzellen', () {
    expect(p('Anzahl Weiselzellen 3'), isA<ZahlKommando>().having((z) => z.feld, 'feld', 'wz_anzahl'));
    expect(p('Weiselzellen schwarmzellen'), isA<EnumKommando>().having((e) => e.wert, 'wert', 'schwarmzellen'));
  });
  test('Auffälligkeit', () {
    expect(p('Auffälligkeit Varroa'), isA<AuffaelligkeitKommando>().having((a) => a.key, 'key', 'varroa_sichtbar'));
  });
  test('Kontext trennt Grammatik', () => expect(p('Brutbild geschlossen', SprachKontext.kontext), isNull));
  test('weisel-Kollision (ganzwortig)', () {
    expect((p('Weisel gesehen') as BoolKommando).feld, 'koenigin');           // Dialekt: Weisel = Königin
    expect(p('Weiselzellen schwarmzellen'), isA<EnumKommando>().having((e) => e.feld, 'feld', 'weiselzellen'));
  });
  test('Zahl vor dem Feldwort', () => expect((p('22 Grad', SprachKontext.kontext) as ZahlKommando).wert, 22));
  test('unbekannt → null', () => expect(p('das Wetter ist schön'), isNull));
}
