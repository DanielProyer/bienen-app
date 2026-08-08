import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/spracheingabe/presentation/providers/spracheingabe_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';

class SpracheingabePage extends ConsumerWidget {
  const SpracheingabePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spracheingabe'),
          bottom: const TabBar(
            labelColor: BeeTokens.textPrimaer,
            unselectedLabelColor: BeeTokens.textGedaempft,
            indicatorColor: BeeTokens.honig,
            tabs: [
              Tab(text: 'Üben'),
              Tab(text: 'Frei sprechen'),
              Tab(text: 'Auswertung'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _UebenAnsicht(),
          EmptyState(
            icon: Icons.mic_none,
            titel: 'Frei sprechen kommt als Nächstes',
            text: 'Hier wirst du reden können wie am Volk und danach '
                'korrigieren, was die Erkennung verhört hat.',
          ),
          EmptyState(
            icon: Icons.insights_outlined,
            titel: 'Die Auswertung kommt zuletzt',
            text: 'Hier stehen später der Bestand, der Vergleich aller '
                'Anbieter und die gelernten Regeln.',
          ),
        ]),
      ),
    );
  }
}

class _UebenAnsicht extends ConsumerWidget {
  const _UebenAnsicht();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(drillProvider);

    return zustand.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        titel: 'Der Übungsstapel liess sich nicht laden',
        text: '$e',
      ),
      data: (d) {
        final karte = d.karte;
        if (karte == null) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            titel: 'Keine Übungskarten',
            text: 'Der Startstapel wird beim ersten Öffnen angelegt. '
                'Erscheint hier nichts, fehlt die Schreibberechtigung.',
          );
        }
        final ergebnis = d.letztes;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(BeeTokens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeeTokens.lg),
                  child: Text(
                    karte.sollText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: BeeTokens.textPrimaer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BeeTokens.md),
              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  key: const Key('drill_aufnahme'),
                  onPressed: () async {
                    final n = ref.read(drillProvider.notifier);
                    if (d.laeuft) {
                      await n.aufnahmeBeenden();
                    } else {
                      await n.aufnahmeStarten();
                    }
                  },
                  icon: Icon(d.laeuft ? Icons.stop : Icons.mic),
                  label: Text(d.laeuft ? 'Fertig' : 'Sprechen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: d.laeuft ? BeeTokens.gefahrText : BeeTokens.honig,
                  ),
                ),
              ),
              if (ergebnis != null) ...[
                const SizedBox(height: BeeTokens.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          ergebnis.getroffen ? Icons.check_circle : Icons.cancel,
                          color: ergebnis.getroffen ? BeeTokens.erfolgText : BeeTokens.gefahrText,
                        ),
                        const SizedBox(width: BeeTokens.sm),
                        Text(
                          ergebnis.getroffen ? 'Verstanden' : 'Nicht verstanden',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ]),
                      const SizedBox(height: BeeTokens.sm),
                      Text('Erkannt: „${ergebnis.transkript}"',
                          style: const TextStyle(color: BeeTokens.textSekundaer)),
                      if (ergebnis.wortfehler != null)
                        Text(
                          'Wortfehlerrate: ${(ergebnis.wortfehler! * 100).round()} %',
                          style: const TextStyle(color: BeeTokens.textSekundaer),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: BeeTokens.sm),
                OutlinedButton(
                  key: const Key('drill_naechste'),
                  onPressed: () => ref.read(drillProvider.notifier).naechste(),
                  child: const Text('Nächste Karte'),
                ),
              ],
              const SizedBox(height: BeeTokens.lg),
              Text(
                '${d.stapel.length} Karten im Stapel · geübt: ${d.bilanz.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BeeTokens.textGedaempft),
              ),
            ],
          ),
        );
      },
    );
  }
}
