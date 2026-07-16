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
/// Reine Funktion (public), damit sie ohne Riverpod-Container testbar ist.
ConstructionProgress progressFor(
    List<ConstructionStep> steps, List<BuildStepContent> defs) {
  final keys = {for (final d in defs) d.key};
  final done = steps.where((s) => s.isDone && keys.contains(s.stepKey)).length;
  return (done: done, total: defs.length);
}

final constructionProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return progressFor(steps, kBuildSteps);
});

final honigverarbeitungProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return progressFor(steps, kHonigverarbeitungSteps);
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

  /// Fehler NICHT mehr schlucken: ein stiller _seedData-Fallback maskierte
  /// Auth-/RLS-Fehler (RLS liefert 0 Zeilen statt Fehler; ein echter Fehler
  /// sah aus wie "alles da"). Fehler gehen als AsyncError an die UI.
  Future<List<ConstructionStep>> _fetch() async {
    final response = await SupabaseConfig.client
        .from('construction_steps')
        .select()
        .order('sort_order', ascending: true);
    return (response as List)
        .map((j) => ConstructionStep.fromJson(j as Map<String, dynamic>))
        .toList();
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

  /// Pfad ist mandanten-praefixiert. WICHTIG: stepKey ist ein STATISCHER,
  /// im Code fest verdrahteter Schluessel ('daemmung', 'hv_planung', ...) —
  /// ohne `<betrieb_id>/`-Praefix wuerden zwei Mandanten desselben Bauschritts
  /// mit upsert:true auf exakt denselben Objektpfad schreiben und sich
  /// gegenseitig ueberschreiben (kein Angriff noetig, das passiert im
  /// Normalbetrieb). Die Storage-Policies (A10) erzwingen das Praefix zusaetzlich.
  Future<void> attachPhoto(
      String stepKey, Uint8List bytes, String betriebId) async {
    final path = '$betriebId/$stepKey.jpg';
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
