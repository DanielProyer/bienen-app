import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/chart_data_provider.dart';

class WeightChart extends ConsumerWidget {
  const WeightChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightSpots = ref.watch(weightChartDataProvider);
    final tempSpots = ref.watch(temperatureChartDataProvider);
    final range = ref.watch(weightRangeProvider);
    final timeRange = ref.watch(timeRangeProvider);
    final timeLabels = ref.watch(chartTimeLabelProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: AppColors.brown600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gewichtsverlauf',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.brown600,
                      ),
                ),
                const Spacer(),
                _TimeRangeChips(selected: timeRange),
              ],
            ),
            const SizedBox(height: 20),
            if (weightSpots.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart,
                          size: 48, color: AppColors.brown100),
                      const SizedBox(height: 8),
                      Text(
                        'Noch keine Messdaten vorhanden',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brown300,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daten werden angezeigt sobald die Waage verbunden ist',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.brown300,
                                ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _weightInterval(range),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.brown50,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${value.toStringAsFixed(0)} kg',
                              style: TextStyle(
                                color: AppColors.brown300,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final match = timeLabels
                                .where((l) =>
                                    (l.position - value).abs() <
                                    _labelThreshold(timeRange))
                                .toList();
                            if (match.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                match.first.label,
                                style: TextStyle(
                                  color: AppColors.brown300,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: range.min,
                    maxY: range.max,
                    lineBarsData: [
                      // Weight line
                      LineChartBarData(
                        spots: weightSpots,
                        isCurved: true,
                        curveSmoothness: 0.2,
                        color: AppColors.honey,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.honey.withAlpha(30),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} kg',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _weightInterval(({double min, double max}) range) {
    final span = range.max - range.min;
    if (span > 20) return 5;
    if (span > 10) return 2;
    return 1;
  }

  double _labelThreshold(TimeRange range) {
    switch (range) {
      case TimeRange.week:
        return 12; // ~12h tolerance
      case TimeRange.month:
        return 24;
      case TimeRange.quarter:
        return 48;
    }
  }
}

class _TimeRangeChips extends ConsumerWidget {
  final TimeRange selected;

  const _TimeRangeChips({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: TimeRange.values.map((range) {
        final isSelected = range == selected;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: FilterChip(
            label: Text(_label(range)),
            selected: isSelected,
            onSelected: (_) {
              ref.read(timeRangeProvider.notifier).state = range;
              ref.read(weightReadingsProvider.notifier).refresh();
            },
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(fontSize: 11),
          ),
        );
      }).toList(),
    );
  }

  String _label(TimeRange range) {
    switch (range) {
      case TimeRange.week:
        return '7T';
      case TimeRange.month:
        return '30T';
      case TimeRange.quarter:
        return '90T';
    }
  }
}
