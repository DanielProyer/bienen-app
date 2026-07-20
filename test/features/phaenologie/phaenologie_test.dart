import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';

void main() {
  test('Katalog-Invarianten: je Anker >=1, Defaults existieren + anker stimmt, referenzDoy 1..366', () {
    expect(indikatorenFuer(PhaenoAnker.fruehjahr), isNotEmpty);
    expect(indikatorenFuer(PhaenoAnker.tracht), isNotEmpty);
    final df = indikatorVon(kDefaultIndikatorFruehjahr);
    final dt = indikatorVon(kDefaultIndikatorTracht);
    expect(df?.anker, PhaenoAnker.fruehjahr);
    expect(dt?.anker, PhaenoAnker.tracht);
    for (final i in kIndikatorpflanzen) {
      expect(i.referenzDoy, inInclusiveRange(1, 366), reason: i.key);
    }
    expect(indikatorVon('gibtsnicht'), isNull);
  });

  test('doyVon: DST-immun, Schaltjahr-tolerant', () {
    expect(doyVon(DateTime(2026, 1, 1)), 1);
    expect(doyVon(DateTime(2026, 3, 15)), 74);   // Nicht-Schaltjahr: salweide-Referenz
    expect(doyVon(DateTime(2026, 6, 9)), 160);   // alpenrose-Referenz
    expect(doyVon(DateTime(2024, 2, 29)), 60);   // Schaltjahr kein Crash
    expect(doyVon(DateTime(2024, 3, 15)), 75);   // Schaltjahr: +1 nach 29.2.
  });

  test('honigreinheitHinweis: nur mit Fenster + gewarnter Futterart im Fenster', () {
    final fenster = (DateTime(2026, 6, 15), DateTime(2026, 7, 25));
    // kein Fenster -> nie
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: null), HonigreinheitHinweis.keiner);
    // Zucker (3:2) im Fenster -> Verfälschung
    expect(honigreinheitHinweis(futterart: 'zuckerwasser_3_2', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.verfaelschung);
    // Notfütterung -> weicherer Hinweis
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'notfuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.notfuetterung);
    // zuckerwasser_1_1 (Jungvolk-Anfüttern) -> kein Fehlalarm
    expect(honigreinheitHinweis(futterart: 'zuckerwasser_1_1', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.keiner);
    // ausserhalb Fenster -> nie
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'auffuetterung',
        datum: DateTime(2026, 9, 1), trachtFenster: fenster), HonigreinheitHinweis.keiner);
  });
}
