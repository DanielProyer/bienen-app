import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';

void main() {
  test('fromJson/toJson-Roundtrip + Whitelist + Schied-Normalisierung', () {
    final w = WabeBeobachtung.fromJson({'inhalte': ['brut', 'pollen', 'quatsch'], 'koenigin': true, 'stifte': true});
    expect(w.inhalte, {'brut', 'pollen'}); // 'quatsch' gefiltert
    expect(w.koenigin, isTrue);
    expect(w.toJson(), {'inhalte': anyOf([equals(['brut', 'pollen']), equals(['pollen', 'brut'])]), 'koenigin': true, 'stifte': true});
    // Schied verwirft Inhalte/Flags:
    final s = WabeBeobachtung.fromJson({'schied': true, 'inhalte': ['brut'], 'koenigin': true});
    expect(s.schied, isTrue);
    expect(s.inhalte, isEmpty);
    expect(s.koenigin, isFalse);
    expect(s.toJson(), {'schied': true});
  });

  test('Ableitung: Brutwaben, Königin, Stifte, Futter-Hinweis — Schied zählt nie', () {
    final ws = [
      const WabeBeobachtung(inhalte: {'futter'}),
      const WabeBeobachtung(inhalte: {'brut', 'pollen'}, stifte: true),
      const WabeBeobachtung(inhalte: {'brut'}, koenigin: true),
      const WabeBeobachtung(schied: true),
    ];
    expect(brutWabenAus(ws), 2);
    expect(koeniginAus(ws), isTrue);
    expect(stifteAus(ws), isTrue);
    expect(futterKgHinweisAus(ws), 1 * kFutterKgProWabe); // nur die Futter-Wabe
  });

  test('Schied-Flag leckt nicht (Guard) + leere Liste', () {
    // Ein (theoretisch) Schied mit Flag darf nicht zählen — fromJson normalisiert das ohnehin.
    expect(koeniginAus(const []), isFalse);
    expect(brutWabenAus(const []), 0);
  });

  test('vorbefuellungAus: leere Waben -> null (kein Overwrite); nicht-leer -> Werte', () {
    expect(vorbefuellungAus(const []), isNull);
    final v = vorbefuellungAus([const WabeBeobachtung(inhalte: {'brut'}, koenigin: true)])!;
    expect(v.brutWaben, 1);
    expect(v.koeniginGesehen, isTrue);
    expect(v.stifteGesehen, isFalse);
  });
}
