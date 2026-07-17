import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_card.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class VoelkerPage extends ConsumerWidget {
  const VoelkerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voelkerListProvider);
    final aktive = ref.watch(aktiveVoelkerProvider);
    final darfSchreiben = ref.watch(darfSchreibenProvider);
    // Stammdaten vorwaermen, damit die Formular-Dropdowns beim ersten Oeffnen
    // bereits gefuellt sind (AsyncNotifier laedt sonst erst beim ersten Read).
    ref.watch(standorteProvider);
    ref.watch(koeniginnenProvider);
    ref.watch(betriebsEinstellungenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voelker')),
      floatingActionButton: darfSchreiben
          ? FloatingActionButton(
              onPressed: () => showVolkForm(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Fehler: $e'),
            TextButton(
              onPressed: () => ref.invalidate(voelkerListProvider),
              child: const Text('Erneut versuchen'),
            ),
          ]),
        ),
        data: (_) => aktive.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Noch keine Voelker.'),
                  if (darfSchreiben)
                    FilledButton(
                      onPressed: () => showVolkForm(context, ref),
                      child: const Text('Erstes Volk anlegen'),
                    ),
                ]),
              )
            : ListView(
                children: [
                  for (final v in aktive)
                    VolkCard(volk: v, onTap: () => context.go('/voelker/${v.id}')),
                ],
              ),
      ),
    );
  }
}
