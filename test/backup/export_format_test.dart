import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/backup/domain/export_format.dart';

void main() {
  test('csvVon: BOM, sortierte Spalten, alles gequotet', () {
    final csv = csvVon([
      {'b': 2, 'a': 'x'},
      {'b': 1, 'a': 'y'},
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    final zeilen = csv.substring(1).trim().split('\n');
    expect(zeilen.first, '"a","b"');
    expect(zeilen.length, 3);
  });

  test('csvVon: Anfuehrungszeichen verdoppelt, null leer', () {
    final csv = csvVon([
      {'a': 'sagt "hallo"', 'b': null},
    ]);
    expect(csv.contains('"sagt ""hallo"""'), isTrue);
    expect(csv.trim().endsWith(',""'), isTrue);
  });

  test('csvVon: leere Liste ergibt nur BOM', () {
    expect(csvVon(const []), '﻿');
  });

  test('stabilesJson: nach id sortiert, Schluessel alphabetisch', () {
    final json = stabilesJson([
      {'name': 'zweit', 'id': '2'},
      {'name': 'erst', 'id': '1'},
    ]);
    expect(json.indexOf('"id": "1"') < json.indexOf('"id": "2"'), isTrue);
    expect(json.indexOf('"id"') < json.indexOf('"name"'), isTrue);
    expect(json.endsWith('\n'), isTrue);
  });

  test('manifestVon: Pflichtfelder + Warnungen', () {
    final m = manifestVon(
      betriebId: 'b1',
      erstelltAm: DateTime.utc(2026, 7, 22, 10),
      tabellen: {'voelker': 1},
      fotoAnzahl: 3,
      fotoBytes: 99,
      schema: {
        'voelker': ['id'],
      },
      warnungen: ['x'],
    );
    expect(m.contains('"format_version": 1'), isTrue);
    expect(m.contains('"betrieb_id": "b1"'), isTrue);
    expect(m.contains('2026-07-22T10:00:00.000Z'), isTrue);
    expect(m.contains('"warnungen"'), isTrue);
    expect(m.endsWith('\n'), isTrue);
  });
}
