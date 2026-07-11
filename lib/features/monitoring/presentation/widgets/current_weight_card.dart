import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

class CurrentWeightCard extends ConsumerWidget {
  const CurrentWeightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestReadingProvider);
    final dailyChange = ref.watch(dailyWeightChangeProvider);
    final nf = NumberFormat('#,##0.0', 'de_CH');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined,
                    color: AppColors.brown600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Aktuelles Gewicht',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.brown600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (latest != null) ...[
              Text(
                '${nf.format(latest.weightKg)} kg',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown800,
                    ),
              ),
              const SizedBox(height: 8),
              if (dailyChange != null)
                _DeltaChip(deltaKg: dailyChange),
              const SizedBox(height: 8),
              Text(
                latest.hiveName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brown300,
                    ),
              ),
              Text(
                'Letzte Messung: ${DateFormat('dd.MM. HH:mm', 'de_CH').format(latest.recordedAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brown300,
                    ),
              ),
            ] else
              Text(
                'Keine Daten',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.brown300,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double deltaKg;

  const _DeltaChip({required this.deltaKg});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('+#,##0.0;-#,##0.0', 'de_CH');
    final isPositive = deltaKg >= 0;
    final color = isPositive ? AppColors.green600 : Colors.red.shade600;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${nf.format(deltaKg)} kg / 24h',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
