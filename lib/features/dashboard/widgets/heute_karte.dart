import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alle = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
    final naechste = naechsteOffene(alle, 3);
    final vorschlaege = ref.watch(vorschlaegeProvider).length;
    final darfSchreiben = ref.watch(darfSchreibenProvider);
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.task_alt, size: 20, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Heute & demnächst', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/aufgaben'), child: const Text('alle →')),
            ]),
            if (naechste.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Keine offenen Aufgaben. 🐝', style: TextStyle(color: AppColors.brown300)),
              ),
            for (final a in naechste)
              Row(children: [
                if (darfSchreiben)
                  Checkbox(value: false, onChanged: (_) => _abhaken(context, ref, a))
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.brown300),
                  ),
                Expanded(child: Text(a.titel, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                if (a.volkId != null) ...[
                  for (final v in voelker)
                    if (v.id == a.volkId)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('🐝 ${v.name}',
                            style: const TextStyle(fontSize: 11, color: AppColors.honeyDark)),
                      ),
                ],
                Text(DateFormat('dd.MM.').format(a.faelligAm),
                    style: TextStyle(
                        fontSize: 12,
                        color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300,
                        fontWeight: a.faelligAm.isBefore(h) ? FontWeight.w600 : FontWeight.w400)),
              ]),
            if (vorschlaege > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () => context.go('/aufgaben'),
                  child: Text('✨ $vorschlaege Saisonvorschläge warten',
                      style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
