import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/monitoring/data/models/weight_reading.dart';
import 'package:bienen_app/features/monitoring/data/models/scale.dart';
import 'package:bienen_app/features/monitoring/data/models/scale_alert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Time range selection for chart
enum TimeRange { week, month, quarter }

final timeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.week);

// Main readings provider
final weightReadingsProvider =
    AsyncNotifierProvider<WeightReadingsNotifier, List<WeightReading>>(
        WeightReadingsNotifier.new);

// Scales provider
final scalesProvider =
    AsyncNotifierProvider<ScalesNotifier, List<Scale>>(ScalesNotifier.new);

// Alerts provider (unacknowledged)
final activeAlertsProvider = Provider<List<ScaleAlert>>((ref) {
  final alertsAsync = ref.watch(allAlertsProvider);
  return (alertsAsync.valueOrNull ?? [])
      .where((a) => !a.acknowledged)
      .toList();
});

final allAlertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<ScaleAlert>>(
        AlertsNotifier.new);

// Derived: latest reading per scale
final latestReadingProvider = Provider<WeightReading?>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.isEmpty) return null;
  return readings.first; // already sorted by recorded_at DESC
});

// Derived: daily weight change
final dailyWeightChangeProvider = Provider<double?>((ref) {
  final readings = ref.watch(weightReadingsProvider).valueOrNull ?? [];
  if (readings.length < 2) return null;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final todayReadings =
      readings.where((r) => r.recordedAt.isAfter(todayStart)).toList();
  final yesterdayReadings = readings
      .where((r) =>
          r.recordedAt.isAfter(yesterdayStart) &&
          r.recordedAt.isBefore(todayStart))
      .toList();

  if (todayReadings.isEmpty || yesterdayReadings.isEmpty) {
    // Fallback: compare latest with 24h ago
    final latest = readings.first;
    final dayAgo = now.subtract(const Duration(hours: 24));
    final oldReading = readings.where((r) => r.recordedAt.isBefore(dayAgo));
    if (oldReading.isEmpty) return null;
    return latest.weightKg - oldReading.first.weightKg;
  }

  return todayReadings.first.weightKg - yesterdayReadings.first.weightKg;
});

class WeightReadingsNotifier extends AsyncNotifier<List<WeightReading>> {
  StreamSubscription? _subscription;

  @override
  Future<List<WeightReading>> build() async {
    ref.onDispose(() => _subscription?.cancel());
    _setupRealtimeSubscription();
    return _fetchReadings();
  }

  Future<List<WeightReading>> _fetchReadings() async {
    final timeRange = ref.read(timeRangeProvider);
    final since = _sinceDate(timeRange);

    try {
      final response = await SupabaseConfig.client
          .from('weight_readings')
          .select()
          .gte('recorded_at', since.toIso8601String())
          .order('recorded_at', ascending: false);

      return (response as List)
          .map((json) =>
              WeightReading.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = SupabaseConfig.client
        .from('weight_readings')
        .stream(primaryKey: ['id'])
        .order('recorded_at', ascending: false)
        .listen((data) {
          final readings = data
              .map((json) => WeightReading.fromJson(json))
              .toList();
          if (readings.isNotEmpty) {
            state = AsyncData(readings);
          }
        });
  }

  DateTime _sinceDate(TimeRange range) {
    final now = DateTime.now();
    switch (range) {
      case TimeRange.week:
        return now.subtract(const Duration(days: 7));
      case TimeRange.month:
        return now.subtract(const Duration(days: 30));
      case TimeRange.quarter:
        return now.subtract(const Duration(days: 90));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchReadings());
  }
}

class ScalesNotifier extends AsyncNotifier<List<Scale>> {
  @override
  Future<List<Scale>> build() async {
    try {
      final response =
          await SupabaseConfig.client.from('scales').select();
      return (response as List)
          .map((json) => Scale.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateScale(Scale scale) async {
    try {
      await SupabaseConfig.client
          .from('scales')
          .upsert(scale.toJson());
      ref.invalidateSelf();
    } catch (_) {}
  }
}

class AlertsNotifier extends AsyncNotifier<List<ScaleAlert>> {
  @override
  Future<List<ScaleAlert>> build() async {
    try {
      final response = await SupabaseConfig.client
          .from('scale_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) =>
              ScaleAlert.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> acknowledge(String alertId) async {
    // Optimistic update
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final a in current)
        if (a.id == alertId)
          ScaleAlert(
            id: a.id,
            scaleId: a.scaleId,
            alertType: a.alertType,
            message: a.message,
            weightReadingId: a.weightReadingId,
            acknowledged: true,
            createdAt: a.createdAt,
          )
        else
          a,
    ]);

    try {
      await SupabaseConfig.client
          .from('scale_alerts')
          .update({'acknowledged': true}).eq('id', alertId);
    } catch (_) {
      state = AsyncData(current);
    }
  }
}
