import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/fake_sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';

/// Baut einen Container mit dem Fake-Erkenner.
(ProviderContainer, FakeSpracheErkenner) _aufbau() {
  final fake = FakeSpracheErkenner();
  final c = ProviderContainer(
      overrides: [spracheErkennerProvider.overrideWithValue(fake)]);
  addTearDown(c.dispose);
  return (c, fake);
}

void main() {
  group('Kommando-Mikro im Einzelsatz-Modus', () {
    test('startet die Erkennung ohne Dauer-Modus', () async {
      final (c, fake) = _aufbau();
      await c.read(sprachControllerProvider.notifier)
          .starten('kmd-kontext', (_) {}, einzelsatz: true);

      expect(fake.zuletztKontinuierlich, isFalse,
          reason: 'ein Kommando ist mit einem Satz fertig — kein Dauerlauf');
    });

    test('stoppt nach dem ersten fertigen Satz von selbst', () async {
      final (c, fake) = _aufbau();
      final gehoert = <String>[];
      await c.read(sprachControllerProvider.notifier)
          .starten('kmd-kontext', gehoert.add, einzelsatz: true);

      fake.sende('Temperatur zwanzig Grad');
      await Future<void>.delayed(Duration.zero);

      expect(gehoert, ['Temperatur zwanzig Grad']);
      expect(fake.aufrufe, contains('stoppen'),
          reason: 'genau das war der gemeldete Loop: Es hörte nie auf');
      expect(c.read(sprachControllerProvider).aktivesMikro, isNull);
    });

    test('vorläufiger Text stoppt noch nicht', () async {
      final (c, fake) = _aufbau();
      await c.read(sprachControllerProvider.notifier)
          .starten('kmd-kontext', (_) {}, einzelsatz: true);

      fake.sende('Temperatur', endgueltig: false);
      await Future<void>.delayed(Duration.zero);

      expect(fake.aufrufe, isNot(contains('stoppen')));
      expect(c.read(sprachControllerProvider).interim, 'Temperatur');
    });
  });

  group('Diktat-Mikro im Dauer-Modus', () {
    test('startet mit Dauer-Modus und läuft nach einem Satz weiter', () async {
      final (c, fake) = _aufbau();
      final gehoert = <String>[];
      await c.read(sprachControllerProvider.notifier)
          .starten('dik-wetter', gehoert.add);

      expect(fake.zuletztKontinuierlich, isTrue);

      fake.sende('schönes Wetter');
      await Future<void>.delayed(Duration.zero);

      expect(gehoert, ['schönes Wetter']);
      expect(fake.aufrufe, isNot(contains('stoppen')),
          reason: 'beim Diktat spricht man weiter');
      expect(c.read(sprachControllerProvider).aktivesMikro, 'dik-wetter');
    });
  });

  group('Zustand folgt dem Erkenner', () {
    test('endet die Erkennung von selbst, fällt der Knopf zurück', () async {
      // Sonst sieht das Mikro aktiv aus, obwohl nichts mehr aufgenommen wird.
      final (c, fake) = _aufbau();
      await c.read(sprachControllerProvider.notifier)
          .starten('dik-wetter', (_) {});
      expect(c.read(sprachControllerProvider).aktivesMikro, 'dik-wetter');

      fake.meldeIdle();
      await Future<void>.delayed(Duration.zero);

      expect(c.read(sprachControllerProvider).aktivesMikro, isNull);
    });

    test('Mikro-Wechsel stoppt das vorherige zuerst', () async {
      final (c, fake) = _aufbau();
      final ctrl = c.read(sprachControllerProvider.notifier);
      await ctrl.starten('dik-wetter', (_) {});
      await ctrl.starten('kmd-kontext', (_) {}, einzelsatz: true);

      expect(fake.aufrufe, ['starten', 'stoppen', 'starten'],
          reason: 'zwei parallele Erkenner waren die Ursache des ersten Loops');
    });
  });
}
