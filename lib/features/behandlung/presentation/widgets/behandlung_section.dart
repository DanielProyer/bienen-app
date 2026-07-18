import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/behandlung/presentation/widgets/varroa_cockpit.dart';

class BehandlungSection extends ConsumerWidget {
  final String volkId;
  const BehandlungSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kontrollen = ref.watch(kontrollenFuerVolkProvider(volkId));
    final behandlungen = ref.watch(behandlungenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Varroa & Behandlung', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf) ...[
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/varroa'),
                icon: const Icon(Icons.biotech, size: 18), label: const Text('Milbendiagnose')),
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/behandlung'),
                icon: const Icon(Icons.medical_services, size: 18), label: const Text('Behandlung')),
            ],
          ]),
          // Cockpit
          switch ((kontrollen, behandlungen)) {
            (AsyncData(value: final ks), AsyncData(value: final bs)) =>
              VarroaCockpit(kontrollen: ks, behandlungen: bs),
            (AsyncError(error: final e), _) || (_, AsyncError(error: final e)) =>
              Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            _ => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          },
          const Divider(),
          // Kompakte Behandlungs-Liste
          behandlungen.maybeWhen(
            data: (bs) => bs.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Behandlung.'))
                : Column(children: [
                    for (final b in bs.take(5))
                      ListTile(
                        dense: true,
                        leading: Icon(b.isStorniert ? Icons.cancel : Icons.medical_services,
                            color: b.isStorniert ? Colors.grey : null),
                        title: Text(
                          '${Wirkstoff.labels[b.wirkstoff] ?? b.wirkstoff} · ${b.praeparat ?? Anwendungsart.labels[b.anwendungsart] ?? ''}',
                          style: b.isStorniert ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null,
                        ),
                        subtitle: Text('${b.datumBeginn.day}.${b.datumBeginn.month}.${b.datumBeginn.year}'
                            '${b.isStorniert ? ' · storniert: ${b.stornoGrund ?? ''}' : ''}'),
                        trailing: (darf && !b.isStorniert)
                            ? IconButton(
                                icon: const Icon(Icons.cancel_outlined, size: 20),
                                tooltip: 'Stornieren',
                                onPressed: () => _storno(context, ref, b.id),
                              )
                            : null,
                      ),
                  ]),
            orElse: () => const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Future<void> _storno(BuildContext context, WidgetRef ref, String id) async {
    final ctrl = TextEditingController();
    final grund = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Behandlung stornieren'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Grund')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Stornieren')),
        ],
      ),
    );
    ctrl.dispose();
    if (grund == null || grund.isEmpty || !context.mounted) return;
    try {
      await ref.read(behandlungenFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
