import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/recherche/domain/recherche_foto.dart';

void main() {
  group('rechercheKeyAusAssetPfad', () {
    test('macht aus dem Asset-Pfad den Dokumentschlüssel', () {
      expect(
        rechercheKeyAusAssetPfad(
            'assets/recherche/30_Varroa_Bildzaehlung_Automatisierung.md'),
        '30_Varroa_Bildzaehlung_Automatisierung',
      );
    });

    test('ohne Ordner und ohne Endung bleibt der Name unverändert', () {
      expect(rechercheKeyAusAssetPfad('15_Varroa'), '15_Varroa');
    });

    test('Endung wird nur am Ende entfernt', () {
      // Ein ".md" mitten im Namen darf nicht abgeschnitten werden.
      expect(rechercheKeyAusAssetPfad('assets/recherche/a.md.b.md'), 'a.md.b');
    });
  });

  group('RechercheFoto.fromJson', () {
    test('liest eine Zeile samt Kapitel-Anker', () {
      final f = RechercheFoto.fromJson({
        'id': 'abc',
        'recherche_key': '30_Varroa',
        'anker': '12-stufe-0',
        'storage_path': 'betrieb/30_Varroa/x.jpg',
        'beschriftung': 'Windel vom 27.07.',
        'created_at': '2026-07-27T20:00:00Z',
      });
      expect(f.anker, '12-stufe-0');
      expect(f.beschriftung, 'Windel vom 27.07.');
      expect(f.rechercheKey, '30_Varroa');
    });

    test('ein Foto ohne Kapitelbezug ist erlaubt', () {
      // anker = null bedeutet: gehört zum Dokument als Ganzes.
      final f = RechercheFoto.fromJson({
        'id': 'abc',
        'recherche_key': '30_Varroa',
        'anker': null,
        'storage_path': 'betrieb/30_Varroa/x.jpg',
        'created_at': '2026-07-27T20:00:00Z',
      });
      expect(f.anker, isNull);
      expect(f.beschriftung, isNull);
    });
  });
}
