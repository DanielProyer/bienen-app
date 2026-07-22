import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

/// Cockpit-Karte „Heute & demnächst": die nächsten 3 offenen Aufgaben, direkt abhakbar.
class HeuteKarte extends ConsumerWidget {
  const HeuteKarte({super.key});

  Future<void> _abhaken(BuildContext context, WidgetRef ref, Aufgabe a) async {
    final notifier = ref.read(aufgabenListProvider.notifier);
    try {
      await notifier.abhaken(a.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('„${a.titel}" erledigt'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            try {
              await notifier.abhaken(a.id, erledigt: false);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            }
          },
        ),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  String? _volkName(List<Volk> voelker, Aufgabe a) {
    if (a.volkId == null) return null;
    for (final v in voelker) {
      if (v.id == a.volkId) return '🐝 ${v.name}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alle = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
    final naechste = naechsteOffene(alle, 3);
    final vorschlaege = ref.watch(vorschlaegeProvider).length;
    final darfSchreiben = ref.watch(darfSchreibenProvider);
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            titel: 'Heute & demnächst',
            action: AppButton(label: 'alle →', kind: AppButtonKind.text, onPressed: () => context.go('/aufgaben')),
          ),
          if (naechste.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeeTokens.sm),
              child: Text('Keine offenen Aufgaben. 🐝', style: TextStyle(color: BeeTokens.textGedaempft)),
            ),
          for (final a in naechste)
            AppListTile(
              leading: darfSchreiben
                  ? Checkbox(value: false, onChanged: (_) => _abhaken(context, ref, a))
                  : const Icon(Icons.radio_button_unchecked, size: 20, color: BeeTokens.textGedaempft),
              titel: a.titel,
              untertitel: _volkName(voelker, a),
              trailing: StatusPill(
                label: DateFormat('dd.MM.').format(a.faelligAm),
                signal: a.faelligAm.isBefore(h) ? BeeSignal.gefahr : BeeSignal.neutral,
              ),
            ),
          if (vorschlaege > 0)
            Padding(
              padding: const EdgeInsets.only(top: BeeTokens.xs),
              child: InkWell(
                onTap: () => context.go('/aufgaben'),
                child: Text('✨ $vorschlaege Saisonvorschläge warten',
                    style: const TextStyle(fontSize: 12, color: BeeTokens.textGedaempft)),
              ),
            ),
        ],
      ),
    );
  }
}
