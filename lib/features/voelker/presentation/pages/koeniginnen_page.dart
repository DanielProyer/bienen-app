import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

/// Königinnen-Register: zeigt ALLE Königinnen — auch die (noch) keinem Volk
/// zugeordneten. Ohne diese Ansicht blieben unzugeordnete Königinnen in der App
/// unsichtbar, weil die Volk-Detailseite nur die zugeordnete Königin zeigt.
class KoeniginnenPage extends ConsumerWidget {
  const KoeniginnenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(koeniginnenProvider);
    final darf = ref.watch(darfSchreibenProvider);
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    final volkName = {for (final v in voelker) v.id: v.name};

    return Scaffold(
      backgroundColor: BeeTokens.oberflaeche,
      appBar: AppBar(title: const Text('Königinnen')),
      floatingActionButton: darf
          ? FloatingActionButton.extended(
              onPressed: () => showKoeniginForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Königin'),
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
            onPressed: () => ref.invalidate(koeniginnenProvider),
          ),
        ),
        data: (alle) {
          if (alle.isEmpty) {
            return EmptyState(
              icon: Icons.workspace_premium_outlined,
              titel: 'Noch keine Königinnen',
              text: 'Lege hier Königinnen an, die (noch) zu keinem Volk gehören — '
                  'oder direkt beim Volk, dann wird sie sofort zugeordnet.',
              aktion: darf
                  ? AppButton(
                      label: 'Königin anlegen',
                      icon: Icons.add,
                      onPressed: () => showKoeniginForm(context, ref),
                    )
                  : null,
            );
          }
          final zugeordnet = alle.where((k) => k.volkId != null).toList();
          final frei = alle.where((k) => k.volkId == null).toList();
          return ListView(
            padding: const EdgeInsets.all(BeeTokens.lg),
            children: [
              if (frei.isNotEmpty) ...[
                SectionHeader(
                    titel: 'Nicht zugeordnet', trailingText: '${frei.length}'),
                for (final k in frei)
                  _KoeniginKarte(koenigin: k, volkName: null, darf: darf),
                const SizedBox(height: BeeTokens.lg),
              ],
              if (zugeordnet.isNotEmpty) ...[
                SectionHeader(
                    titel: 'Einem Volk zugeordnet',
                    trailingText: '${zugeordnet.length}'),
                for (final k in zugeordnet)
                  _KoeniginKarte(
                      koenigin: k, volkName: volkName[k.volkId], darf: darf),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KoeniginKarte extends ConsumerWidget {
  final Koenigin koenigin;
  final String? volkName;
  final bool darf;
  const _KoeniginKarte(
      {required this.koenigin, required this.volkName, required this.darf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = koenigin;
    final teile = <String>[
      if (k.schlupfjahr != null)
        '${k.schlupfjahr} (${jahresfarbe(k.schlupfjahr!).label})',
      if (k.rasse != null) k.rasse!,
      if (k.linie != null) k.linie!,
      k.begattungsart,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppListTile(
          titel: k.kennung?.isNotEmpty == true ? k.kennung! : '(ohne Kennung)',
          untertitel: teile.join(' · '),
          onTap: darf ? () => showKoeniginForm(context, ref, koenigin: k) : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill(
              label: volkName ?? (k.volkId != null ? 'zugeordnet' : 'frei'),
              signal: k.volkId != null ? BeeSignal.erfolg : BeeSignal.neutral,
            ),
            if (darf)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: BeeTokens.textGedaempft),
                tooltip: 'Löschen',
                onPressed: () => _loeschen(context, ref),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref) async {
    final name = koenigin.kennung?.isNotEmpty == true
        ? koenigin.kennung!
        : 'diese Königin';
    // Ist sie zugeordnet, wird das Volk durch das Löschen weisellos
    // (ON DELETE SET NULL) — das muss vorher klar sein.
    final zusatz = koenigin.volkId != null
        ? ' Das Volk «${volkName ?? 'ohne Namen'}» wird dadurch weisellos.'
        : '';
    final ok = await confirmSheet(
      context,
      titel: '$name löschen?',
      text: 'Die Königin wird endgültig aus dem Register entfernt.$zusatz',
      bestaetigenLabel: 'Löschen',
      gefahr: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(koeniginnenProvider.notifier).loeschen(koenigin.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name gelöscht.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
      }
    }
  }
}
