import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';
import 'package:bienen_app/features/fuetterung/presentation/widgets/winterfutter_balken.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class FuetterungSection extends ConsumerWidget {
  final String volkId;
  const FuetterungSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fuetterungenFuerVolkProvider(volkId));
    final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
    final darf = ref.watch(darfSchreibenProvider);
    final zielKg = einst?.winterfutterZielKg ?? 22;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Fütterung', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/fuetterung'),
                icon: const Icon(Icons.water_drop_outlined, size: 18),
                label: const Text('Fütterung erfassen')),
          ]),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WinterfutterBalken(fuetterungen: list, zielKg: zielKg, stichtag: DateTime.now()),
              const Divider(),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Fütterung.'))
              else
                for (final f in list.take(5))
                  ListTile(
                    dense: true,
                    leading: Icon(f.isStorniert ? Icons.cancel : Icons.water_drop_outlined,
                        color: f.isStorniert ? Colors.grey : null),
                    title: Text(
                      '${Zweck.labels[f.zweck] ?? f.zweck} · ${f.mengeProVolkKg} kg · ${Futterart.labels[f.futterart] ?? f.futterart}',
                      style: f.isStorniert
                          ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                          : null,
                    ),
                    subtitle: Text('${f.durchgefuehrtAm.day}.${f.durchgefuehrtAm.month}.${f.durchgefuehrtAm.year}'
                        '${f.bioZertifiziert ? ' · bio' : ''}'
                        '${f.isStorniert ? ' · storniert: ${f.stornoGrund ?? ''}' : ''}'),
                    trailing: (darf && !f.isStorniert)
                        ? IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            tooltip: 'Stornieren',
                            onPressed: () => _storno(context, ref, f.id),
                          )
                        : null,
                  ),
            ]),
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
        title: const Text('Fütterung stornieren'),
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
      await ref.read(fuetterungenFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
