import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_card.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';

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
      appBar: AppBar(
        title: const Text('Völker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Königinnen',
            onPressed: () => context.go('/koeniginnen'),
          ),
        ],
      ),
      floatingActionButton: darfSchreiben
          ? FloatingActionButton(
              onPressed: () => showVolkForm(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          titel: 'Fehler beim Laden',
          text: '$e',
          aktion: AppButton(
            label: 'Erneut versuchen',
            kind: AppButtonKind.sekundaer,
            onPressed: () => ref.invalidate(voelkerListProvider),
          ),
        ),
        data: (_) => aktive.isEmpty
            ? EmptyState(
                icon: Icons.hive_outlined,
                titel: 'Noch keine Völker',
                text: 'Lege dein erstes Volk an, um loszulegen.',
                aktion: darfSchreiben
                    ? AppButton(
                        label: 'Erstes Volk anlegen',
                        icon: Icons.add,
                        onPressed: () => showVolkForm(context, ref),
                      )
                    : null,
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
