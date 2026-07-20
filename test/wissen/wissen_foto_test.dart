import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

void main() {
  test('fromJson parst alle Felder (beschriftung gesetzt)', () {
    final f = WissenFoto.fromJson({
      'id': 'id1', 'wissen_key': 'stifte', 'storage_path': 'b/stifte/foto_1.jpg',
      'beschriftung': 'meine Wabe', 'created_at': '2026-07-20T10:00:00Z',
    });
    expect(f.id, 'id1');
    expect(f.wissenKey, 'stifte');
    expect(f.storagePath, 'b/stifte/foto_1.jpg');
    expect(f.beschriftung, 'meine Wabe');
    expect(f.createdAt.toUtc(), DateTime.utc(2026, 7, 20, 10));
  });
  test('fromJson mit beschriftung null', () {
    final f = WissenFoto.fromJson({
      'id': 'id2', 'wissen_key': 'brut_offen_verdeckelt', 'storage_path': 'b/x/foto_2.jpg',
      'beschriftung': null, 'created_at': '2026-07-20T11:00:00Z',
    });
    expect(f.beschriftung, isNull);
  });
}
