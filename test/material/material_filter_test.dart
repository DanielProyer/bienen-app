import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

void main() {
  MaterialItem m(String id,
          {bool c = false,
          bool a = false,
          String s = 'gekauft',
          double stock = 0,
          double min = 0}) =>
      MaterialItem(
          id: id,
          category: 'x',
          name: id,
          isConsumable: c,
          archiviert: a,
          status: s,
          stockQty: stock,
          minQty: min);

  test('Nachkauf-Praedikat: frisch gekauft mit vollem Bestand ist NICHT faellig',
      () {
    expect(istNachzukaufen(m('a', c: true, stock: 10, min: 2)), isFalse);
    expect(istNachzukaufen(m('b', c: true, stock: 1, min: 2)), isTrue);
    expect(istNachzukaufen(m('c', c: true, a: true, stock: 0, min: 2)), isFalse);
    expect(istNachzukaufen(m('d', c: true, stock: 0, min: 0)), isFalse);
    expect(istNachzukaufen(m('e', c: false, stock: 0, min: 2)), isFalse);
    expect(istNachzukaufen(m('f', c: true, s: 'geplant', stock: 0, min: 2)),
        isFalse);
  });

  test('Typ-Praedikate', () {
    expect(istVerbrauch(m('a', c: true)), isTrue);
    expect(istVerbrauch(m('b', c: true, a: true)), isFalse);
    expect(istAnlage(m('c', c: false)), isTrue);
    expect(istAnlage(m('d', c: false, a: true)), isFalse);
    expect(istArchiviert(m('e', a: true)), isTrue);
  });
}
