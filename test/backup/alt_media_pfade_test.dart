import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/backup/data/export_service.dart';

const _betrieb = '1c84d5dd-1111-2222-3333-444455556666';

void main() {
  test('Alt-Pfade ohne Betriebs-Praefix landen im Export', () {
    final pfade = ExportService.altMediaPfadeAus([
      {'photo_urls': ['e6287d8c/photo_web.jpg', 'e6287d8c/photo_2.jpg']},
    ], _betrieb);
    expect(pfade, {'e6287d8c/photo_web.jpg', 'e6287d8c/photo_2.jpg'});
  });

  test('Pfade mit Betriebs-Praefix nicht doppelt (die Auflistung hat sie schon)',
      () {
    final pfade = ExportService.altMediaPfadeAus([
      {'photo_urls': ['$_betrieb/abc/foto_1.jpg']},
    ], _betrieb);
    expect(pfade, isEmpty);
  });

  test('volle URLs sind keine Storage-Pfade und werden uebersprungen', () {
    final pfade = ExportService.altMediaPfadeAus([
      {
        'photo_urls': [
          'https://x.supabase.co/storage/v1/object/public/material-media/a/b.jpg',
        ],
      },
    ], _betrieb);
    expect(pfade, isEmpty);
  });

  test('leere/fehlende Werte werfen nicht', () {
    expect(
        ExportService.altMediaPfadeAus([
          {'photo_urls': null},
          {'photo_urls': const <String>[]},
          {'photo_urls': const ['', '   ']},
          const <String, dynamic>{},
        ], _betrieb),
        isEmpty);
  });
}
