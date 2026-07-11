import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/features/monitoring/presentation/widgets/alert_banner.dart';
import 'package:bienen_app/features/monitoring/presentation/widgets/current_weight_card.dart';
import 'package:bienen_app/features/monitoring/presentation/widgets/sensor_status_card.dart';
import 'package:bienen_app/features/monitoring/presentation/widgets/weight_chart.dart';

class MonitoringPage extends ConsumerWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(weightReadingsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockwaage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/monitoring/settings'),
            tooltip: 'Einstellungen',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(weightReadingsProvider.notifier).refresh(),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: readingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 8),
              Text('Fehler beim Laden: $e'),
            ],
          ),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () =>
              ref.read(weightReadingsProvider.notifier).refresh(),
          child: _buildContent(context, isWide),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isWide) {
    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AlertBanner(),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 2, child: CurrentWeightCard()),
                const SizedBox(width: 16),
                const Expanded(flex: 2, child: SensorStatusCard()),
              ],
            ),
            const SizedBox(height: 16),
            const WeightChart(),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        AlertBanner(),
        SizedBox(height: 8),
        CurrentWeightCard(),
        SizedBox(height: 12),
        SensorStatusCard(),
        SizedBox(height: 12),
        WeightChart(),
        SizedBox(height: 24),
      ],
    );
  }
}
