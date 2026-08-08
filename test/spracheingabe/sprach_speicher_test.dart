import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_speicher.dart';

void main() {
  test('der Pfad folgt <betrieb>/<person>/<datei>', () {
    final p = probenPfad(betriebId: 'b1', personId: 'u1', dateiname: 'x.webm');
    expect(p, 'b1/u1/x.webm');
  });

  test('der Pfad beginnt mit der Betriebs-ID — sonst greift der CHECK nicht', () {
    // storage_path like (betrieb_id || '/' || person_id || '/%')
    final p = probenPfad(betriebId: 'b1', personId: 'u1', dateiname: 'x.webm');
    expect(p.startsWith('b1/u1/'), isTrue);
  });

  test('leere Angaben werden abgelehnt statt einen kaputten Pfad zu bauen', () {
    expect(() => probenPfad(betriebId: '', personId: 'u1', dateiname: 'x.webm'),
        throwsArgumentError);
    expect(() => probenPfad(betriebId: 'b1', personId: '', dateiname: 'x.webm'),
        throwsArgumentError);
    expect(() => probenPfad(betriebId: 'b1', personId: 'u1', dateiname: '  '),
        throwsArgumentError);
  });

  test('der Dateiname endet auf die Endung des Formats', () {
    expect(probenDateiname(mime: 'audio/webm', kennung: 'abc'), 'abc.webm');
    expect(probenDateiname(mime: 'audio/mp4', kennung: 'abc'), 'abc.mp4');
    expect(probenDateiname(mime: 'audio/unbekannt', kennung: 'abc'), 'abc.webm');
  });
}
