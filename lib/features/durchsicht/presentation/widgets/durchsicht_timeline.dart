import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/durchsicht/presentation/widgets/durchsicht_karte.dart';

class DurchsichtTimeline extends ConsumerWidget {
  final String volkId;
  const DurchsichtTimeline({super.key, required this.volkId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(durchsichtenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Verlauf (Durchsichten)', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/durchsicht'),
                icon: const Icon(Icons.add), label: const Text('Durchsicht')),
          ]),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Durchsicht.'))
                : Column(children: [
                    for (final d in list)
                      DurchsichtKarte(d: d, onTap: () => context.go('/voelker/$volkId/durchsicht/${d.id}')),
                  ]),
          ),
        ]),
      ),
    );
  }
}
