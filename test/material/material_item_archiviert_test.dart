import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';

void main() {
  test('archiviert round-trip', () {
    final m = MaterialItem.fromJson(
        {'id': '1', 'category': 'c', 'name': 'n', 'archiviert': true});
    expect(m.archiviert, isTrue);
    expect(m.toJson()['archiviert'], isTrue);
    expect(
        MaterialItem.fromJson({'id': '2', 'category': 'c', 'name': 'n'})
            .archiviert,
        isFalse); // Default
  });
}
