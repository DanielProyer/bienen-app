import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/widgets/meldepflicht_banner.dart';

class GesundheitSection extends ConsumerWidget {
  final String volkId;
  const GesundheitSection({super.key, required this.volkId});

  static Color _katColor(Rechtskategorie? r) => switch (r) {
        Rechtskategorie.zuBekaempfen => Colors.red,
        Rechtskategorie.zuUeberwachen => Colors.orange,
        Rechtskategorie.neobiotaMeldung => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gesundheitFuerVolkProvider(volkId));
    final aktivMelde = ref.watch(aktiveMeldepflichtProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    final letzte = ref.watch(letzteDurchsichtMapProvider)[volkId];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Gesundheit', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/gesundheit'),
                icon: const Icon(Icons.medical_information_outlined, size: 18),
                label: const Text('Diagnose erfassen')),
          ]),
          // Meldepflicht-Banner (aktive meldepflichtige Ereignisse; nach Krankheit dedupliziert)
          for (final key in {for (final e in aktivMelde) e.krankheit}) MeldepflichtBanner(krankheitKey: key),
          // 4.3-Nudge: je gesundheitsrelevantem Flag der letzten Durchsicht ohne aktives Ereignis gleicher Krankheit
          // (nur wenn die Gesundheitsliste geladen ist — sonst würde der Nudge kurz trotz aktivem Ereignis erscheinen)
          if (darf && letzte != null && async.hasValue)
            ..._nudges(context, async.valueOrNull ?? const [], letzte.auffaelligkeiten),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Keine Gesundheitsereignisse.'))
                : Column(children: [
                    for (final e in list.take(6))
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.circle, size: 12,
                            color: e.isStorniert ? Colors.grey : _katColor(rechtskategorieVon(e.krankheit))),
                        title: Text('${katalogEintrag(e.krankheit)?.label ?? e.krankheit} · ${e.status}',
                            style: e.isStorniert
                                ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                                : null),
                        subtitle: Text('${e.festgestelltAm.day}.${e.festgestelltAm.month}.${e.festgestelltAm.year}'
                            '${e.isStorniert ? ' · storniert: ${e.stornoGrund ?? ''}' : ''}'),
                        trailing: (darf && !e.isStorniert)
                            ? IconButton(icon: const Icon(Icons.cancel_outlined, size: 20), tooltip: 'Stornieren',
                                onPressed: () => _storno(context, ref, e.id))
                            : null,
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _nudges(BuildContext context, List<Gesundheitsereignis> ereignisse, List<String> flags) {
    final aktiveKrankheiten =
        ereignisse.where((e) => e.istAktiv).map((e) => e.krankheit).toSet();
    final out = <Widget>[];
    final gesehen = <String>{};
    for (final flag in flags) {
      final key = durchsichtFlagZuKrankheit(flag);
      if (key == null || aktiveKrankheiten.contains(key) || !gesehen.add(key)) continue;
      final label = katalogEintrag(key)?.label ?? key;
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Expanded(child: Text('Durchsicht meldete: $label', style: const TextStyle(fontSize: 13))),
          TextButton(
            onPressed: () => context.go('/voelker/$volkId/gesundheit?k=$key'),
            child: const Text('als Diagnose erfassen')),
        ]),
      ));
    }
    return out;
  }

  Future<void> _storno(BuildContext context, WidgetRef ref, String id) async {
    final ctrl = TextEditingController();
    final grund = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnose stornieren'),
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
      await ref.read(gesundheitFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
