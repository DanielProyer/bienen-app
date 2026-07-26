import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/storage/foto_quelle.dart';

void main() {
  test('volle URL wird direkt verwendet', () {
    expect(istVolleUrl('https://x.supabase.co/storage/v1/object/public/b/p.jpg'), isTrue);
    expect(istVolleUrl('http://x/p.jpg'), isTrue);
  });

  test('Pfad muss signiert werden', () {
    expect(istVolleUrl('1c84d5dd-aaaa/abc/foto_1.jpg'), isFalse);
    expect(istVolleUrl('e6287d8c/photo_web.jpg'), isFalse);
  });

  test('leer/Unsinn gilt nicht als URL', () {
    expect(istVolleUrl(''), isFalse);
    expect(istVolleUrl('   '), isFalse);
    expect(istVolleUrl('httpsohneschema/p.jpg'), isFalse);
  });
}
