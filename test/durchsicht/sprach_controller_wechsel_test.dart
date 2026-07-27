import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/fake_sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';

void main() {
  late FakeSpracheErkenner fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeSpracheErkenner();
    container = ProviderContainer(
      overrides: [spracheErkennerProvider.overrideWithValue(fake)],
    );
  });
  tearDown(() => container.dispose());

  SprachController ctrl() => container.read(sprachControllerProvider.notifier);

  test('Mikro-Wechsel stoppt zuerst den laufenden Erkenner', () async {
    // Der gemeldete Fehler: Im Wizard von der Durchsicht zum Wetter wechseln,
    // dort das Mikro antippen — zwei Erkenner liefen parallel und starteten
    // sich endlos gegenseitig neu.
    await ctrl().starten('durchsicht', (_) {});
    await ctrl().starten('wetter', (_) {});

    expect(fake.aufrufe, ['starten', 'stoppen', 'starten'],
        reason: 'vor dem zweiten Start muss ein stoppen liegen');
    expect(container.read(sprachControllerProvider).aktivesMikro, 'wetter');
  });

  test('dasselbe Mikro erneut starten stoppt nicht doppelt', () async {
    // Kein überflüssiges Stoppen — das würde ein laufendes Diktat abschneiden.
    await ctrl().starten('durchsicht', (_) {});
    await ctrl().starten('durchsicht', (_) {});
    expect(fake.aufrufe, ['starten', 'starten']);
  });

  test('stoppen setzt das aktive Mikro zurück', () async {
    await ctrl().starten('durchsicht', (_) {});
    await ctrl().stoppen();
    expect(container.read(sprachControllerProvider).aktivesMikro, isNull);
    expect(fake.aufrufe.last, 'stoppen');
  });

  test('Endtext geht an den Rückruf des ZULETZT gestarteten Mikros', () async {
    // Sonst landet das Diktat der Wetter-Seite im Notizfeld der Durchsicht.
    final gehoert = <String>[];
    await ctrl().starten('durchsicht', (t) => gehoert.add('durchsicht:$t'));
    await ctrl().starten('wetter', (t) => gehoert.add('wetter:$t'));

    fake.sende('sonnig');
    await Future<void>.delayed(Duration.zero);

    expect(gehoert, ['wetter:sonnig']);
  });
}
