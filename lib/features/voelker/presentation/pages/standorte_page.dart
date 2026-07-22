import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

/// Standort-Register: zeigt ALLE Stände — auch die (noch) keinem Volk
/// zugeordneten. Ohne diese Ansicht blieben freie Stände in der App unsichtbar
/// und damit unkorrigierbar, weil die Volk-Detailseite nur den zugeordneten
/// Stand zeigt.
class StandortePage extends ConsumerWidget {
  const StandortePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(standorteProvider);
    final darf = ref.watch(darfSchreibenProvider);
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    final aufgaben = ref.watch(aufgabenListProvider).valueOrNull ?? const [];

    // Wie viele Völker/Aufgaben hängen an welchem Stand? Das ist die Zahl, die
    // beim Löschen ihren Standort verliert (ON DELETE SET NULL).
    final voelkerJeStandort = <String, int>{};
    for (final v in voelker) {
      if (v.standortId != null) {
        voelkerJeStandort[v.standortId!] = (voelkerJeStandort[v.standortId!] ?? 0) + 1;
      }
    }
    final aufgabenJeStandort = <String, int>{};
    for (final a in aufgaben) {
      if (a.standortId != null) {
        aufgabenJeStandort[a.standortId!] = (aufgabenJeStandort[a.standortId!] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: BeeTokens.oberflaeche,
      appBar: AppBar(title: const Text('Standorte')),
      floatingActionButton: darf
          ? FloatingActionButton.extended(
              onPressed: () => showStandortForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Standort'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          titel: 'Fehler beim Laden',
          text: '$e',
          aktion: AppButton(
            label: 'Erneut versuchen',
            kind: AppButtonKind.sekundaer,
            onPressed: () => ref.invalidate(standorteProvider),
          ),
        ),
        data: (alle) {
          if (alle.isEmpty) {
            return EmptyState(
              icon: Icons.place_outlined,
              titel: 'Noch keine Standorte',
              text: 'Lege hier Stände an, die (noch) zu keinem Volk gehören — '
                  'oder direkt beim Volk, dann wird er sofort zugeordnet.',
              aktion: darf
                  ? AppButton(
                      label: 'Standort anlegen',
                      icon: Icons.add,
                      onPressed: () => showStandortForm(context, ref),
                    )
                  : null,
            );
          }
          final aktiv = alle.where((s) => s.status != 'aufgeloest').toList();
          final aufgeloest = alle.where((s) => s.status == 'aufgeloest').toList();
          Widget karte(Standort s) => _StandortKarte(
                standort: s,
                anzahlVoelker: voelkerJeStandort[s.id] ?? 0,
                anzahlAufgaben: aufgabenJeStandort[s.id] ?? 0,
                darf: darf,
              );
          return ListView(
            padding: const EdgeInsets.all(BeeTokens.lg),
            children: [
              if (aktiv.isNotEmpty) ...[
                SectionHeader(titel: 'In Betrieb', trailingText: '${aktiv.length}'),
                for (final s in aktiv) karte(s),
                const SizedBox(height: BeeTokens.lg),
              ],
              if (aufgeloest.isNotEmpty) ...[
                SectionHeader(titel: 'Aufgelöst', trailingText: '${aufgeloest.length}'),
                for (final s in aufgeloest) karte(s),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StandortKarte extends ConsumerWidget {
  final Standort standort;
  final int anzahlVoelker;
  final int anzahlAufgaben;
  final bool darf;
  const _StandortKarte({
    required this.standort,
    required this.anzahlVoelker,
    required this.anzahlAufgaben,
    required this.darf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = standort;
    final teile = <String>[
      // Amtliche Standnummer: Pflichtangabe gegenueber dem Veterinaeramt —
      // fehlt sie, muss das sichtbar sein.
      s.amtlicheStandnummer?.isNotEmpty == true
          ? 'Standnr. ${s.amtlicheStandnummer}'
          : 'Standnr. fehlt',
      if (s.hoeheM != null) '${s.hoeheM} m',
      if (s.adresse?.isNotEmpty == true) s.adresse!,
      anzahlVoelker == 1 ? '1 Volk' : '$anzahlVoelker Völker',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppListTile(
            titel: s.name.isNotEmpty ? s.name : '(ohne Namen)',
            untertitel: teile.join(' · '),
            onTap: darf ? () => showStandortForm(context, ref, standort: s) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusPill(label: s.status, signal: _signal(s.status)),
              if (darf)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: BeeTokens.textGedaempft),
                  tooltip: 'Löschen',
                  onPressed: () => _loeschen(context, ref),
                ),
            ]),
          ),
          if (s.sperrbezirk)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  BeeTokens.md, 0, BeeTokens.md, BeeTokens.md),
              child: Row(children: const [
                Icon(Icons.warning_amber_outlined,
                    size: 16, color: BeeTokens.gefahrText),
                SizedBox(width: BeeTokens.sm),
                Expanded(
                  child: Text('Sperrbezirk — Wanderung gesperrt',
                      style: TextStyle(fontSize: 13, color: BeeTokens.gefahrText)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  static BeeSignal _signal(String status) => switch (status) {
        'besetzt' => BeeSignal.erfolg,
        'unbesetzt' => BeeSignal.neutral,
        _ => BeeSignal.warnung,
      };

  Future<void> _loeschen(BuildContext context, WidgetRef ref) async {
    final name = standort.name.isNotEmpty ? standort.name : 'diesen Standort';
    // Voelker UND Aufgaben verlieren beim Loeschen ihren Standort
    // (ON DELETE SET NULL) — das muss vorher konkret auf dem Tisch liegen.
    final folgen = <String>[
      if (anzahlVoelker > 0)
        anzahlVoelker == 1 ? '1 Volk' : '$anzahlVoelker Völker',
      if (anzahlAufgaben > 0)
        anzahlAufgaben == 1 ? '1 Aufgabe' : '$anzahlAufgaben Aufgaben',
    ];
    final zusatz = folgen.isEmpty
        ? ''
        : ' ${folgen.join(' und ')} verlieren dadurch den Standort '
            '(sie bleiben erhalten, stehen aber ohne Stand da).';
    final ok = await confirmSheet(
      context,
      titel: '$name löschen?',
      text: 'Der Standort wird endgültig entfernt.$zusatz',
      bestaetigenLabel: 'Löschen',
      gefahr: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(standorteProvider.notifier).loeschen(standort.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name gelöscht.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
      }
    }
  }
}
