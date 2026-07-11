import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_weight_outlined,
                        size: 64, color: AppColors.brown100),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Waage konfiguriert',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.brown600,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sobald eine Stockwaage angeschlossen ist, '
                      'erscheinen hier die Einstellungen.\n\n'
                      'Geplant: HiveWatch oder BroodMinder Integration.',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.brown300,
                              ),
                    ),
                    const SizedBox(height: 24),
                    _InfoCard(
                      title: 'Architektur',
                      items: const [
                        'Vendor-agnostisch (HiveWatch / BroodMinder)',
                        'Supabase Edge Function pollt Vendor-API',
                        'Realtime-Updates in der App',
                        'Schwarm-Alerts bei >1 kg/h Verlust',
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scales.length,
            itemBuilder: (context, index) {
              final scale = scales[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monitor_weight,
                              color: AppColors.honey),
                          const SizedBox(width: 8),
                          Text(
                            scale.hiveName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(scale.vendor),
                            backgroundColor: AppColors.amber50,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.brown300,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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
    return Card(
      color: AppColors.amber50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.honeyDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('  •  ',
                          style: TextStyle(color: AppColors.honeyDark)),
                      Expanded(
                        child: Text(
                          item,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.brown600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
