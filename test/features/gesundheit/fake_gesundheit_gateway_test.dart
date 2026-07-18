import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

void main() {
  test('speichern/stornieren; Storno erhält foto_urls', () async {
    final g = FakeGesundheitGateway();
    await g.speichern(Gesundheitsereignis(
        id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb',
        status: 'verdacht', fotoUrls: const ['b/v1/f.jpg']));
    var list = await g.ereignisseFuerVolk('v1');
    expect(list.length, 1);
    expect(list.first.istAktiv, isTrue);

    await g.stornieren(list.first.id, 'Fehleingabe');
    list = await g.ereignisseFuerVolk('v1');
    expect(list.first.isStorniert, isTrue);
    expect(list.first.fotoUrls, const ['b/v1/f.jpg']); // Foto-Spur bleibt
    expect(list.first.istAktiv, isFalse);
  });
  test('Foto-Helfer als No-Op nutzbar', () async {
    final g = FakeGesundheitGateway();
    final pfad = await g.fotoHochladen(betriebId: 'b', gruppeId: 'v1', bytes: Uint8List(0));
    expect(pfad, contains('b/v1/'));
    expect(await g.fotoSignedUrl(pfad), startsWith('https://signed.test/'));
    await g.fotoEntfernen([pfad]); // wirft nicht
  });
}
