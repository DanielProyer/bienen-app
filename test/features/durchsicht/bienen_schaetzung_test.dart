import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/bienen_schaetzung.dart';

void main() {
  test('~1000 Bienen je besetzter Wabengasse (Dadant-Richtwert)', () {
    expect(bienenSchaetzung(0), 0);
    expect(bienenSchaetzung(1), 1000);
    expect(bienenSchaetzung(8.5), 8500);
    expect(bienenSchaetzung(null), isNull);
  });
}
