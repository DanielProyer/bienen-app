import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

final constructionStepsProvider =
    AsyncNotifierProvider<ConstructionStepsNotifier, List<ConstructionStep>>(
        ConstructionStepsNotifier.new);

typedef ConstructionProgress = ({int done, int total});

ConstructionProgress constructionProgress(List<ConstructionStep> steps) {
  final done = steps.where((s) => s.isDone).length;
  return (done: done, total: kBuildSteps.length);
}

final constructionProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return constructionProgress(steps);
});

/// Fortschritt je stepKey für schnellen Zugriff in der UI.
final constructionProgressMapProvider =
    Provider<Map<String, ConstructionStep>>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return {for (final s in steps) s.stepKey: s};
});

class ConstructionStepsNotifier extends AsyncNotifier<List<ConstructionStep>> {
  static const _bucket = 'construction-photos';

  @override
  Future<List<ConstructionStep>> build() => _fetch();

  Future<List<ConstructionStep>> _fetch() async {
    try {
      final response = await SupabaseConfig.client
          .from('construction_steps')
          .select()
          .order('sort_order', ascending: true);
      return (response as List)
          .map((j) => ConstructionStep.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seedData;
    }
  }

  Future<void> toggleDone(String stepKey, bool done) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.stepKey == stepKey) s.copyWith(isDone: done) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'is_done': done}).eq('step_key', stepKey);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateNote(String stepKey, String note) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.stepKey == stepKey) s.copyWith(note: note) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'note': note}).eq('step_key', stepKey);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> attachPhoto(String stepKey, Uint8List bytes) async {
    final path = '$stepKey.jpg';
    await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final base = SupabaseConfig.client.storage.from(_bucket).getPublicUrl(path);
    final takenAt = DateTime.now();
    // Cache-Bust, damit ein ersetztes Foto sofort/nach Reload neu geladen wird.
    final url = '$base?v=${takenAt.millisecondsSinceEpoch}';

    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.stepKey == stepKey)
          s.copyWith(photoUrl: url, photoTakenAt: takenAt)
        else
          s,
    ]);
    try {
      await SupabaseConfig.client.from('construction_steps').update({
        'photo_url': url,
        'photo_taken_at': takenAt.toIso8601String(),
      }).eq('step_key', stepKey);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}

// Fallback-Fortschritt (falls Supabase nicht erreichbar): alle 12 Schritte offen.
final _seedData = <ConstructionStep>[
  for (var i = 0; i < kBuildSteps.length; i++)
    ConstructionStep(stepKey: kBuildSteps[i].key, sortOrder: i),
];
