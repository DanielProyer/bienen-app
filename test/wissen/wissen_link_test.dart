import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

void main() {
  test('WissensLink verlangt genau eine Quelle', () {
    expect(() => WissensLink(label: 'x'), throwsA(isA<AssertionError>()));
    expect(() => WissensLink(label: 'x', rechercheAsset: 'a', url: 'b'), throwsA(isA<AssertionError>()));
    expect(const WissensLink(label: 'x', rechercheAsset: 'a').rechercheAsset, 'a');
    expect(const WissensLink(label: 'y', url: 'https://z').url, 'https://z');
  });
}
