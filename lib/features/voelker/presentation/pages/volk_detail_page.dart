import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/presentation/widgets/behandlung_section.dart';
import 'package:bienen_app/features/durchsicht/presentation/widgets/durchsicht_timeline.dart';
import 'package:bienen_app/features/fuetterung/presentation/widgets/fuetterung_section.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/koenigin_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/standort_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

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
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (list) {
        final idx = list.indexWhere((v) => v.id == volkId);
        if (idx < 0) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Volk nicht gefunden.')),
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
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Stammdaten', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Status: ${volk.status}'),
                    Text('Beute: ${volk.beutentyp ?? '—'} · Zargen: ${volk.zargen ?? '—'} · Brutwaben: ${volk.brutwaben ?? '—'}'),
                    Text('Bio: ${volk.bioStatus} · Gesundheit: ${volk.gesundheitsstatus}'),
                  ]),
                ),
              ),
              KoeniginSection(volk: volk),
              StandortSection(volk: volk),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text(scale == null ? 'Keine Waage verknuepft' : 'Waage: ${scale.hiveName}'),
                  onTap: scale == null ? null : () => context.go('/monitoring'),
                ),
              ),
              DurchsichtTimeline(volkId: volk.id),
              BehandlungSection(volkId: volk.id),
              FuetterungSection(volkId: volk.id),
            ],
          ),
        );
      },
    );
  }
}
