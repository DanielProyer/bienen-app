import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/vermehrung/presentation/providers/vermehrung_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class VermehrungSektion extends ConsumerWidget {
  final String volkId;
  const VermehrungSektion({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darf = ref.watch(darfSchreibenProvider);
    final ereignisse = (ref.watch(vermehrungListProvider).valueOrNull ?? const [])
        .where((e) => e.stammvolkId == volkId || e.jungvolkId == volkId).toList();
    final aufgaben = ref.watch(aufgabenListProvider).valueOrNull ?? const [];
    final andere = (ref.watch(voelkerListProvider).valueOrNull ?? const []).where((v) => v.id != volkId).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Vermehrung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        if (darf)
          TextButton.icon(onPressed: () => context.go('/voelker/$volkId/vermehrung'),
              icon: const Icon(Icons.add, size: 18), label: const Text('Ableger erfassen')),
      ]),
      if (ereignisse.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch keine Vermehrung erfasst.', style: TextStyle(color: AppColors.brown300))),
      for (final e in ereignisse)
        Builder(builder: (_) {
          final n = (kVermehrungsKetten[e.methode] ?? const []).length;
          final x = aufgaben.where((a) => a.quelle == 'ereignis' && a.ereignisId == e.id).length;
          final rolle = e.stammvolkId == volkId ? 'Stammvolk' : 'Jungvolk';
          return Card(child: ListTile(
            title: Text('${kVermehrungsMethoden[e.methode]?.label ?? e.methode} · $rolle'),
            subtitle: Text('${DateFormat('dd.MM.yyyy').format(e.erstelltAm)} · $x/$n Schritte'
                '${e.jungvolkId == null ? ' · Jungvolk nicht verknüpft' : ''}'),
            trailing: darf ? PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'link') {
                  await _jungvolkWaehlen(context, ref, e.id, andere);
                } else if (v == 'del') {
                  await _loeschen(context, ref, e.id);
                }
              },
              itemBuilder: (_) => [
                if (e.jungvolkId == null) const PopupMenuItem(value: 'link', child: Text('Jungvolk verknüpfen')),
                const PopupMenuItem(value: 'del', child: Text('Löschen')),
              ],
            ) : null,
          ));
        }),
    ]);
  }

  Future<void> _jungvolkWaehlen(BuildContext context, WidgetRef ref, String id, List<dynamic> andere) async {
    final gewaehlt = await showDialog<String>(context: context, builder: (_) => SimpleDialog(
      title: const Text('Jungvolk verknüpfen'),
      children: [for (final v in andere) SimpleDialogOption(onPressed: () => Navigator.pop(context, v.id as String), child: Text(v.name as String))],
    ));
    if (gewaehlt != null) {
      try { await ref.read(vermehrungListProvider.notifier).jungvolkVerknuepfen(id, gewaehlt); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Ereignis löschen?'),
      content: const Text('Entfernt das Ereignis und seine Ketten-Aufgaben (auch erledigte). Erfasste Behandlungen im Journal bleiben erhalten.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
      ],
    ));
    if (ok == true) {
      try { await ref.read(vermehrungListProvider.notifier).loeschen(id); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }
}
