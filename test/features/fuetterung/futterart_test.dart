import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

void main() {
  // Muss identisch zu I02-CHECK UND F02-RPC-Whitelist sein (Drift-Schutz).
  const dbUndRpc = {'zuckerwasser_1_1','zuckerwasser_3_2','invertsirup','futterteig','futterwaben','honig','sonstige'};
  test('Futterart.werte == DB-CHECK == RPC-Whitelist', () {
    expect(Futterart.werte.toSet(), dbUndRpc);
  });
  test('jeder Wert hat ein Label', () {
    for (final w in Futterart.werte) { expect(Futterart.labels[w], isNotNull); }
  });
}
