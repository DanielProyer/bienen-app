import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';

void main() {
  test('Ziffern', () {
    expect(deutscheZahl('22'), 22);
    expect(deutscheZahl('0'), 0);
    expect(deutscheZahl('3.5'), 3.5);
  });
  test('Zahlwörter 0-99', () {
    expect(deutscheZahl('null'), 0);
    expect(deutscheZahl('drei'), 3);
    expect(deutscheZahl('zwoelf'), 12);
    expect(deutscheZahl('zwanzig'), 20);
    expect(deutscheZahl('zweiundzwanzig'), 22);
    expect(deutscheZahl('einunddreissig'), 31);
  });
  test('kein Treffer', () {
    expect(deutscheZahl('haus'), isNull);
    expect(deutscheZahl(''), isNull);
  });
}
