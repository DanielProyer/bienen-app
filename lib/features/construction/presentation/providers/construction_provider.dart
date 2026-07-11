import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

/// Kategorien im Bau-Tab. Erweiterbar – später evtl. Werkstatt / Lager /
/// Bienenunterstand (noch nicht geklärt).
enum BauKategorie { bienenstand, honigverarbeitung }

final selectedBauKategorieProvider =
    StateProvider<BauKategorie>((ref) => BauKategorie.bienenstand);

final constructionStepsProvider =
    AsyncNotifierProvider<ConstructionStepsNotifier, List<ConstructionStep>>(
        ConstructionStepsNotifier.new);

typedef ConstructionProgress = ({int done, int total});

/// Fortschritt nur über die Schritte eines Bereichs (Bienenstand ODER
/// Honigverarbeitung) – beide liegen in derselben Tabelle, per step_key getrennt.
ConstructionProgress _progressFor(
    List<ConstructionStep> steps, List<BuildStepContent> defs) {
  final keys = {for (final d in defs) d.key};
  final done = steps.where((s) => s.isDone && keys.contains(s.stepKey)).length;
  return (done: done, total: defs.length);
}

final constructionProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return _progressFor(steps, kBuildSteps);
});

final honigverarbeitungProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return _progressFor(steps, kHonigverarbeitungSteps);
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

// Fallback-Fortschritt (falls Supabase nicht erreichbar): alle Schritte offen.
final _seedData = <ConstructionStep>[
  for (var i = 0; i < kBuildSteps.length; i++)
    ConstructionStep(stepKey: kBuildSteps[i].key, sortOrder: i),
  for (var i = 0; i < kHonigverarbeitungSteps.length; i++)
    ConstructionStep(
        stepKey: kHonigverarbeitungSteps[i].key, sortOrder: 100 + i),
];
