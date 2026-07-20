import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('leere/whitespace query → leer', () {
    expect(sucheWissen(''), isEmpty);
    expect(sucheWissen('   '), isEmpty);
  });
  test('diakritik-normalisiert', () {
    expect(sucheWissen('koenigin').map((e) => e.key), contains('koenigin_finden'));
    expect(sucheWissen('königin').map((e) => e.key), contains('koenigin_finden'));
  });
  test('trifft Stichwort', () {
    expect(sucheWissen('varroa').map((e) => e.key), contains('baurahmen_drohnen'));
  });
}
