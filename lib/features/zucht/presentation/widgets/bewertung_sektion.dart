import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/presentation/providers/bewertung_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

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
      SectionHeader(
        titel: 'Bewertung',
        action: darf
            ? AppButton(
                label: 'Bewerten',
                icon: Icons.star_border,
                kind: AppButtonKind.text,
                onPressed: () => context.go('/voelker/$volkId/bewertung'),
              )
            : null,
      ),
      if (agg == null)
        const Padding(padding: EdgeInsets.symmetric(vertical: BeeTokens.sm),
            child: Text('Noch nicht bewertet.', style: TextStyle(color: BeeTokens.textGedaempft)))
      else ...[
        Text('Gesamtnote Saison $saison: ${agg.gesamtnote.toStringAsFixed(1)} / 4  (${agg.anzahl}×)',
            style: const TextStyle(fontWeight: FontWeight.w600, color: BeeTokens.textSekundaer)),
        const SizedBox(height: 6),
        for (final a in kBewertungsAchsen)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 120, child: Text(a.label, style: const TextStyle(fontSize: 12, color: BeeTokens.textPrimaer))),
              Expanded(child: LinearProgressIndicator(value: agg.achsen[a.key]! / 4, minHeight: 6)),
              const SizedBox(width: BeeTokens.sm),
              Text(agg.achsen[a.key]!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: BeeTokens.textPrimaer)),
            ])),
      ],
      const SizedBox(height: BeeTokens.sm),
      for (final b in alle)
        Padding(
          padding: const EdgeInsets.only(bottom: BeeTokens.sm),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: AppListTile(
              titel: DateFormat('dd.MM.yyyy').format(b.bewertetAm),
              untertitel: _untertitel(b),
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
            ),
          ),
        ),
    ]);
  }

  String _untertitel(VolkBewertung b) {
    final werte = [for (final a in kBewertungsAchsen) '${a.label[0]}${b.wertFuer(a.key)}'].join(' · ');
    return b.notiz != null ? '$werte — ${b.notiz}' : werte;
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref, String id) async {
    final ok = await confirmSheet(
      context,
      titel: 'Bewertung löschen?',
      bestaetigenLabel: 'Löschen',
      gefahr: true,
    );
    if (ok) {
      try { await ref.read(bewertungenProvider.notifier).loeschen(id); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }
}
