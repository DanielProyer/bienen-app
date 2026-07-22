import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/presentation/widgets/aufgaben_section.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/presentation/widgets/behandlung_section.dart';
import 'package:bienen_app/features/durchsicht/presentation/widgets/durchsicht_timeline.dart';
import 'package:bienen_app/features/fuetterung/presentation/widgets/fuetterung_section.dart';
import 'package:bienen_app/features/gesundheit/presentation/widgets/gesundheit_section.dart';
import 'package:bienen_app/features/vermehrung/presentation/widgets/vermehrung_sektion.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/koenigin_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/standort_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';
import 'package:bienen_app/features/zucht/presentation/widgets/bewertung_sektion.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

class VolkDetailPage extends ConsumerWidget {
  final String volkId;
  const VolkDetailPage({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voelkerListProvider);
    final darf = ref.watch(darfSchreibenProvider);
    final scale = ref.watch(scaleFuerVolkProvider(volkId));
    // Stammdaten vorwaermen fuer die Formular-Dropdowns/Vorbelegungen.
    ref.watch(standorteProvider);
    ref.watch(koeniginnenProvider);
    ref.watch(betriebsEinstellungenProvider);

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: EmptyState(icon: Icons.error_outline, titel: 'Fehler beim Laden', text: '$e'),
      ),
      data: (list) {
        final idx = list.indexWhere((v) => v.id == volkId);
        if (idx < 0) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.search_off, titel: 'Volk nicht gefunden'),
          );
        }
        final volk = list[idx];
        return Scaffold(
          appBar: AppBar(
            title: Text(volk.name),
            actions: [
              if (darf)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => showVolkForm(context, ref, volk: volk),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(BeeTokens.md),
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Stammdaten', style: BeeTokens.abschnitt),
                  const SizedBox(height: BeeTokens.sm),
                  Align(alignment: Alignment.centerLeft, child: StatusPill(label: volk.status)),
                  const SizedBox(height: BeeTokens.sm),
                  Text('Beute: ${volk.beutentyp ?? '—'} · Zargen: ${volk.zargen ?? '—'} · Brutwaben: ${volk.brutwaben ?? '—'}'),
                  Text('Bio: ${volk.bioStatus} · Gesundheit: ${volk.gesundheitsstatus}'),
                ]),
              ),
              KoeniginSection(volk: volk),
              StandortSection(volk: volk),
              AufgabenSection(volkId: volk.id),
              AppCard(
                padding: EdgeInsets.zero,
                child: AppListTile(
                  leading: const Icon(Icons.monitor_weight_outlined, color: BeeTokens.textGedaempft),
                  titel: scale == null ? 'Keine Waage verknuepft' : 'Waage: ${scale.hiveName}',
                  onTap: scale == null ? null : () => context.go('/monitoring'),
                ),
              ),
              DurchsichtTimeline(volkId: volk.id),
              BehandlungSection(volkId: volk.id),
              FuetterungSection(volkId: volk.id),
              GesundheitSection(volkId: volk.id),
              const SizedBox(height: BeeTokens.sm),
              VermehrungSektion(volkId: volk.id),
              const SizedBox(height: BeeTokens.sm),
              BewertungSektion(volkId: volk.id),
            ],
          ),
        );
      },
    );
  }
}
