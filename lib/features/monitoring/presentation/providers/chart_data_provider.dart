import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/monitoring/data/models/weight_reading.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

// Chart data points for weight
final weightChartDataProvider = Provider<List<FlSpot>>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.isEmpty) return [];

  // Readings are DESC, reverse for chart (oldest first)
  final sorted = readings.reversed.toList();
  final baseTime = sorted.first.recordedAt.millisecondsSinceEpoch.toDouble();

  return sorted.map((r) {
    final x =
        (r.recordedAt.millisecondsSinceEpoch.toDouble() - baseTime) /
            (1000 * 60 * 60); // hours since first reading
    return FlSpot(x, r.weightKg);
  }).toList();
});

// Chart data points for temperature
final temperatureChartDataProvider = Provider<List<FlSpot>>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.isEmpty) return [];

  final sorted = readings.reversed.toList();
  final baseTime = sorted.first.recordedAt.millisecondsSinceEpoch.toDouble();

  return sorted
      .where((r) => r.temperatureC != null)
      .map((r) {
        final x =
            (r.recordedAt.millisecondsSinceEpoch.toDouble() - baseTime) /
                (1000 * 60 * 60);
        return FlSpot(x, r.temperatureC!);
      })
      .toList();
});

// Weight range for Y axis
final weightRangeProvider = Provider<({double min, double max})>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.isEmpty) return (min: 0, max: 100);

  final weights = readings.map((r) => r.weightKg).toList();
  final min = weights.reduce((a, b) => a < b ? a : b);
  final max = weights.reduce((a, b) => a > b ? a : b);
  final padding = (max - min) * 0.1;

  return (
    min: (min - padding).clamp(0, double.infinity),
    max: max + padding,
  );
});

// Time labels for X axis
final chartTimeLabelProvider =
    Provider<List<({double position, String label})>>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.isEmpty) return [];

  final sorted = readings.reversed.toList();
  final baseTime = sorted.first.recordedAt.millisecondsSinceEpoch.toDouble();

  // Create labels for each day
  final labels = <({double position, String label})>[];
  DateTime? lastDate;

  for (final r in sorted) {
    final date =
        DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    if (lastDate == null || date != lastDate) {
      final x =
          (r.recordedAt.millisecondsSinceEpoch.toDouble() - baseTime) /
              (1000 * 60 * 60);
      labels.add((
        position: x,
        label: '${date.day}.${date.month}.',
      ));
      lastDate = date;
    }
  }

  return labels;
});
