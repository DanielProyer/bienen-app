import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/aufgaben/presentation/widgets/vorschlag_karte.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/vermehrung/presentation/providers/vermehrung_provider.dart';
import 'package:bienen_app/features/vermehrung/presentation/widgets/ketten_vorschlag_karte.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

class AufgabenPage extends ConsumerWidget {
  const AufgabenPage({super.key});

  static const _gruppenTitel = {
    AufgabenGruppe.ueberfaellig: 'Überfällig',
    AufgabenGruppe.heute: 'Heute',
    AufgabenGruppe.demnaechst: 'Demnächst',
    AufgabenGruppe.spaeter: 'Später',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aufgabenListProvider);
    final vorschlaege = ref.watch(vorschlaegeProvider);
    final ketten = ref.watch(kettenVorschlaegeProvider);
    final darfSchreiben = ref.watch(darfSchreibenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      floatingActionButton: darfSchreiben
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/aufgaben/neu'),
              icon: const Icon(Icons.add),
              label: const Text('Neue Aufgabe'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, titel: 'Fehler beim Laden', text: '$e'),
        data: (alle) {
          final gruppen = gruppiereOffene(alle, DateTime.now());
          final erledigt = _kuerzlichErledigt(alle);
          final leer = alle.isEmpty && vorschlaege.isEmpty && ketten.isEmpty;
          return ListView(
            padding: const EdgeInsets.all(BeeTokens.lg),
            children: [
              if (darfSchreiben && vorschlaege.isNotEmpty) ...[
                const SectionHeader(titel: 'Saisonaufgaben'),
                ...vorschlaege.map((v) => VorschlagKarte(vorschlag: v)),
                const SizedBox(height: BeeTokens.lg),
              ],
              if (darfSchreiben && ketten.isNotEmpty) ...[
                const SectionHeader(titel: 'Vermehrung'),
                ...ketten.map((v) => KettenVorschlagKarte(vorschlag: v)),
                const SizedBox(height: BeeTokens.lg),
              ],
              if (leer)
                const Padding(
                  padding: EdgeInsets.only(top: BeeTokens.xxl),
                  child: EmptyState(
                    icon: Icons.check_circle_outline,
                    titel: 'Keine Aufgaben',
                    text: 'Alles im grünen Bereich. 🐝',
                  ),
                ),
              for (final g in AufgabenGruppe.values)
                if (gruppen[g]!.isNotEmpty) ...[
                  SectionHeader(titel: _gruppenTitel[g]!),
                  ...gruppen[g]!.map((a) => _AufgabeZeile(
                      aufgabe: a,
                      ueberfaellig: g == AufgabenGruppe.ueberfaellig,
                      darfSchreiben: darfSchreiben)),
                  const SizedBox(height: BeeTokens.md),
                ],
              if (erledigt.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Erledigt & Übersprungen (${erledigt.length})',
                      style: const TextStyle(fontSize: 14, color: BeeTokens.textGedaempft)),
                  children: [
                    for (final a in erledigt)
                      _AufgabeZeile(aufgabe: a, ueberfaellig: false, darfSchreiben: darfSchreiben),
                  ],
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  /// Erledigte/übersprungene der letzten 30 Tage (übersprungene Regel-Marker ohne Volk zeigen wir mit).
  List<Aufgabe> _kuerzlichErledigt(List<Aufgabe> alle) {
    final grenze = DateTime.now().subtract(const Duration(days: 30));
    return alle.where((a) {
      if (a.status == 'erledigt') return a.erledigtAm != null && a.erledigtAm!.isAfter(grenze);
      if (a.status == 'uebersprungen') return a.faelligAm.isAfter(grenze);
      return false;
    }).toList()
      ..sort((a, b) => b.faelligAm.compareTo(a.faelligAm));
  }
}

class _AufgabeZeile extends ConsumerWidget {
  final Aufgabe aufgabe;
  final bool ueberfaellig;
  final bool darfSchreiben;
  const _AufgabeZeile({required this.aufgabe, required this.ueberfaellig, required this.darfSchreiben});

  static const _kategorieLabel = {
    'durchsicht': 'Durchsicht', 'behandlung': 'Behandlung', 'fuetterung': 'Fütterung',
    'schutz': 'Schutz', 'werkstatt': 'Werkstatt', 'verwaltung': 'Verwaltung', 'sonstiges': 'Sonstiges',
  };

  /// Fälligkeit → Signal: überfällig = gefahr, heute = warnung, sonst (künftig/erledigt) = neutral.
  BeeSignal _faelligSignal(bool erledigt, bool uebersprungen) {
    if (erledigt || uebersprungen) return BeeSignal.neutral;
    if (ueberfaellig) return BeeSignal.gefahr;
    final now = DateTime.now();
    final h = DateTime(now.year, now.month, now.day);
    final f = DateTime(aufgabe.faelligAm.year, aufgabe.faelligAm.month, aufgabe.faelligAm.day);
    return f == h ? BeeSignal.warnung : BeeSignal.neutral;
  }

  Future<void> _abhaken(BuildContext context, WidgetRef ref, bool erledigt) async {
    final notifier = ref.read(aufgabenListProvider.notifier);
    try {
      await notifier.abhaken(aufgabe.id, erledigt: erledigt);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
      return;
    }
    if (!context.mounted) return;
    if (erledigt) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('„${aufgabe.titel}" erledigt'),
        action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () async {
              try {
                await notifier.abhaken(aufgabe.id, erledigt: false);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              }
            }),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    String? volkName;
    for (final v in voelker) {
      if (v.id == aufgabe.volkId) {
        volkName = v.name;
        break;
      }
    }
    final erledigt = aufgabe.status == 'erledigt';
    final uebersprungen = aufgabe.status == 'uebersprungen';
    final datum = DateFormat('dd.MM.').format(aufgabe.faelligAm);
    final aktion = regelVon(aufgabe.regelKey)?.aktionRoute;

    final untertitel = <String>[
      _kategorieLabel[aufgabe.kategorie] ?? aufgabe.kategorie,
      if (volkName != null) '🐝 $volkName',
      if (aufgabe.prioritaet == 'hoch' && !erledigt && !uebersprungen) 'PRIO',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppListTile(
          leading: darfSchreiben && !uebersprungen
              ? Checkbox(value: erledigt, onChanged: (v) => _abhaken(context, ref, v ?? false))
              : Icon(uebersprungen ? Icons.skip_next : (erledigt ? Icons.check_circle : Icons.radio_button_unchecked),
                  color: BeeTokens.textGedaempft),
          titel: aufgabe.titel,
          untertitel: untertitel,
          onTap: volkName != null ? () => context.go('/voelker/${aufgabe.volkId}') : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill(label: datum, signal: _faelligSignal(erledigt, uebersprungen)),
            if (darfSchreiben && aktion != null && aufgabe.volkId != null && !erledigt && !uebersprungen)
              IconButton(
                tooltip: 'Erfassen',
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: () => context.go('/voelker/${aufgabe.volkId}/$aktion'),
              ),
            if (darfSchreiben && !uebersprungen)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') context.go('/aufgaben/${aufgabe.id}/bearbeiten');
                  if (v == 'del') _loeschen(context, ref);
                  if (v == 'reopen') _abhaken(context, ref, false);
                },
                itemBuilder: (_) => [
                  if (!erledigt) const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  if (erledigt) const PopupMenuItem(value: 'reopen', child: Text('Wieder öffnen')),
                  const PopupMenuItem(value: 'del', child: Text('Löschen')),
                ],
              ),
            if (darfSchreiben && uebersprungen)
              PopupMenuButton<String>(
                onSelected: (_) => _wiederherstellen(context, ref),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'restore', child: Text('Vorschlag wiederherstellen')),
                ],
              ),
          ]),
        ),
      ),
    );
  }

  /// Übersprungen-Marker löschen → Generator zeigt den Vorschlag wieder an.
  Future<void> _wiederherstellen(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(aufgabenListProvider.notifier).loeschen(aufgabe.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vorschlag wieder aktiv')));
    }
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      titel: 'Aufgabe löschen?',
      text: '„${aufgabe.titel}" wird endgültig gelöscht.',
      bestaetigenLabel: 'Löschen',
      gefahr: true,
    );
    if (ok) await ref.read(aufgabenListProvider.notifier).loeschen(aufgabe.id);
  }
}
