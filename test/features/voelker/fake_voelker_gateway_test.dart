import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';

void main() {
  test('Umweiselung setzt alte auf ersetzt und haengt neue an', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1', kennung: 'A'));
    await gw.koeniginSpeichern(const Koenigin(id: 'k2', kennung: 'B'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));

    await gw.umweiseln(volkId: 'v1', neueKoeniginId: 'k2');

    final v = (await gw.voelker()).firstWhere((x) => x.id == 'v1');
    expect(v.koeniginId, 'k2');
    final k1 = (await gw.koeniginnen()).firstWhere((x) => x.id == 'k1');
    expect(k1.status, 'ersetzt');
  });

  test('Umweiselung ohne neue Koenigin macht Volk weisellos', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));
    await gw.umweiseln(volkId: 'v1', neueKoeniginId: null, altGrund: 'tot');
    final v = (await gw.voelker()).firstWhere((x) => x.id == 'v1');
    expect(v.koeniginId, isNull);
    final k1 = (await gw.koeniginnen()).firstWhere((x) => x.id == 'k1');
    expect(k1.status, 'tot');
  });

  test('Koenigin an zweitem Volk wird abgewiesen (BA022)', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));
    expect(
      () => gw.volkSpeichern(const Volk(id: 'v2', name: 'V2', koeniginId: 'k1')),
      throwsA(isA<VoelkerFehler>().having((e) => e.code, 'code', 'BA022')),
    );
  });
}
