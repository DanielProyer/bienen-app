import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/data/fake_gesundheit_gateway.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';

void main() {
  test('aktiveMeldepflichtProvider liefert nur aktive zu_bekaempfen-Ereignisse', () async {
    final fake = FakeGesundheitGateway();
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'afb'));
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'kalkbrut'));
    await fake.speichern(Gesundheitsereignis(id: '', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'efb', status: 'ausgeheilt'));

    final c = ProviderContainer(overrides: [gesundheitGatewayProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    await c.read(gesundheitFuerVolkProvider('v1').future);
    final aktiv = c.read(aktiveMeldepflichtProvider('v1'));
    expect(aktiv.map((e) => e.krankheit), ['afb']); // kalkbrut=nicht meldepflichtig, efb=abgeschlossen
  });
}
