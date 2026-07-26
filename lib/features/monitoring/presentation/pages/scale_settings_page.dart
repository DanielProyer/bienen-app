import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';

/// Read-only Übersicht der konfigurierten Stockwaagen (Andockpunkt HiveWatch).
/// Kein Formular/Speichern → bewusst kein FormScaffold (keine Bodenleiste).
class ScaleSettingsPage extends ConsumerWidget {
  const ScaleSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scalesAsync = ref.watch(scalesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waagen-Einstellungen'),
      ),
      body: scalesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (scales) {
          if (scales.isEmpty) {
            return const EmptyState(
              icon: Icons.monitor_weight_outlined,
              titel: 'Keine Waage konfiguriert',
              text: 'Sobald eine Stockwaage angeschlossen ist, '
                  'erscheinen hier die Einstellungen.\n\n'
                  'Geplant: HiveWatch oder BroodMinder Integration.',
              aktion: _InfoCard(
                title: 'Architektur',
                items: [
                  'Vendor-agnostisch (HiveWatch / BroodMinder)',
                  'Supabase Edge Function pollt Vendor-API',
                  'Realtime-Updates in der App',
                  'Schwarm-Alerts bei >1 kg/h Verlust',
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(BeeTokens.lg),
            itemCount: scales.length,
            itemBuilder: (context, index) {
              final scale = scales[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: BeeTokens.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monitor_weight,
                              color: BeeTokens.honig, size: 20),
                          const SizedBox(width: BeeTokens.sm),
                          Expanded(
                            child: Text(scale.hiveName,
                                style: BeeTokens.abschnitt),
                          ),
                          Chip(
                            label: Text(scale.vendor,
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: BeeTokens.md),
                      _DetailRow('ID', scale.id),
                      if (scale.location != null)
                        _DetailRow('Standort', scale.location!),
                      _DetailRow(
                        'Schwarm-Schwelle',
                        '${scale.alertSwarmThreshold} kg/h',
                      ),
                      _DetailRow(
                        'Alerts',
                        scale.alertEnabled ? 'Aktiv' : 'Deaktiviert',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.xs),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: BeeTokens.gedaempft),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: BeeTokens.textPrimaer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.honig, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BeeTokens.label),
          const SizedBox(height: BeeTokens.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: BeeTokens.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ',
                        style: TextStyle(color: BeeTokens.textSekundaer)),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13, color: BeeTokens.textPrimaer)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
