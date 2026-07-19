import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';

/// Volk-Detailseite: bis zu 5 offene Aufgaben dieses Volks.
class AufgabenSection extends ConsumerWidget {
  final String volkId;
  const AufgabenSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offene = ref.watch(aufgabenFuerVolkProvider(volkId));
    if (offene.isEmpty) return const SizedBox.shrink();
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
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
                  child: Text('Offene Aufgaben', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/aufgaben'), child: const Text('alle →')),
            ]),
            for (final a in offene.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.radio_button_unchecked,
                      size: 16,
                      color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.titel, style: const TextStyle(fontSize: 13))),
                  Text(DateFormat('dd.MM.').format(a.faelligAm),
                      style: TextStyle(
                          fontSize: 12,
                          color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
