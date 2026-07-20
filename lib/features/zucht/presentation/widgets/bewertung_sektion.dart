import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/presentation/providers/bewertung_provider.dart';

class BewertungSektion extends ConsumerWidget {
  final String volkId;
  const BewertungSektion({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darf = ref.watch(darfSchreibenProvider);
    final alle = ref.watch(bewertungenFuerVolkProvider(volkId));
    final saison = DateTime.now().year;
    final saisonBew = alle.where((b) => b.bewertetAm.year == saison).toList();
    final agg = aggregiereSaison(saisonBew);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Bewertung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        if (darf)
          TextButton.icon(onPressed: () => context.go('/voelker/$volkId/bewertung'),
              icon: const Icon(Icons.star_border, size: 18), label: const Text('Bewerten')),
      ]),
      if (agg == null)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch nicht bewertet.', style: TextStyle(color: AppColors.brown300)))
      else ...[
        Text('Gesamtnote Saison $saison: ${agg.gesamtnote.toStringAsFixed(1)} / 4  (${agg.anzahl}×)',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.honeyDark)),
        const SizedBox(height: 6),
        for (final a in kBewertungsAchsen)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 120, child: Text(a.label, style: const TextStyle(fontSize: 12))),
              Expanded(child: LinearProgressIndicator(value: agg.achsen[a.key]! / 4, minHeight: 6)),
              const SizedBox(width: 8),
              Text(agg.achsen[a.key]!.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ])),
      ],
      const SizedBox(height: 8),
      for (final b in alle)
        Card(child: ListTile(
          dense: true,
          title: Text(DateFormat('dd.MM.yyyy').format(b.bewertetAm)),
          subtitle: Text(_untertitel(b)),
          trailing: darf ? PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') { context.go('/voelker/$volkId/bewertung?b=${b.id}'); }
              else if (v == 'del') { await _loeschen(context, ref, b.id); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'del', child: Text('Löschen')),
            ],
          ) : null,
        )),
    ]);
  }

  String _untertitel(VolkBewertung b) {
    final werte = [for (final a in kBewertungsAchsen) '${a.label[0]}${b.wertFuer(a.key)}'].join(' · ');
    return b.notiz != null ? '$werte — ${b.notiz}' : werte;
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Bewertung löschen?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
      ],
    ));
    if (ok == true) {
      try { await ref.read(bewertungenProvider.notifier).loeschen(id); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }
}
