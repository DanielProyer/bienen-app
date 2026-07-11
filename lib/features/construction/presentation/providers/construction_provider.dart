import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

final constructionStepsProvider =
    AsyncNotifierProvider<ConstructionStepsNotifier, List<ConstructionStep>>(
        ConstructionStepsNotifier.new);

typedef ConstructionProgress = ({int done, int total});

ConstructionProgress constructionProgress(List<ConstructionStep> steps) {
  final done = steps.where((s) => s.isDone).length;
  return (done: done, total: steps.length);
}

final constructionProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return constructionProgress(steps);
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

  Future<void> toggleDone(String id, bool done) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id) s.copyWith(isDone: done) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'is_done': done}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateNote(String id, String note) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id) s.copyWith(note: note) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'note': note}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> attachPhoto(String id, Uint8List bytes) async {
    final path = '$id.jpg';
    await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final base = SupabaseConfig.client.storage.from(_bucket).getPublicUrl(path);
    final takenAt = DateTime.now();
    // Cache-Bust, damit das neue Foto sofort angezeigt wird
    final url = '$base?v=${takenAt.millisecondsSinceEpoch}';

    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id)
          s.copyWith(photoUrl: url, photoTakenAt: takenAt)
        else
          s,
    ]);
    try {
      await SupabaseConfig.client.from('construction_steps').update({
        'photo_url': url,
        'photo_taken_at': takenAt.toIso8601String(),
      }).eq('id', id);
    } catch (_) {
      // Revert optimistic state so UI and DB stay consistent
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}

// Fallback-Seed (falls Supabase nicht erreichbar). Reihenfolge = sort_order.
final _seedData = <ConstructionStep>[
  const ConstructionStep(id: '0', phase: 'vorbereitung', fotoCode: 'F00', title: 'Standort vor Baubeginn (Übersicht Fläche + Ausrichtung Südost)', sortOrder: 0),
  const ConstructionStep(id: '1', phase: 'einkauf', fotoCode: 'F01', title: 'Eingekauftes Material komplett ausgelegt (Vollständigkeits-Beleg)', sortOrder: 1),
  const ConstructionStep(id: '2', phase: 'bau', fotoCode: 'F02', title: 'Beide fertigen Doppelbalken, Stossversatz sichtbar', soll: 'Stösse liegen nie übereinander; Balken gerade, kein Verzug', sortOrder: 2),
  const ConstructionStep(id: '3', phase: 'bau', fotoCode: 'F03', title: 'Angezeichnetes Rechteck 2000×400 mit Massband', soll: 'Beinabstand 2000 mm, Balkenachse 400 mm, Diagonalen gleich', sortOrder: 3),
  const ConstructionStep(id: '4', phase: 'bau', fotoCode: 'F04', title: 'Alle 4 Erdschrauben gesetzt (Übersicht)', soll: 'Positionen = Rechteck aus Schritt 2', sortOrder: 4),
  const ConstructionStep(id: '5', phase: 'bau', fotoCode: 'F05', title: 'Wasserwaage an einer Hülse (Lot-Beleg)', soll: 'Jede Erdschraube lotrecht', sortOrder: 5),
  const ConstructionStep(id: '6', phase: 'bau', fotoCode: 'F06', title: 'Durchbolzter Pfosten im U-FIX (Detail)', soll: 'Pfosten fest, grob gleiche Oberkante', sortOrder: 6),
  const ConstructionStep(id: '7', phase: 'bau', fotoCode: 'F07', title: 'Nivellier-Bolzen im Pfostenkopf (Detail)', soll: 'Schraube leichtgängig, Scheibe plan, ±25 mm frei', sortOrder: 7),
  const ConstructionStep(id: '8', phase: 'bau', fotoCode: 'F08', title: 'Laser-/Wasserwaagen-Kontrolle auf dem Balken', soll: 'Balken waagerecht längs UND quer; Kontermuttern fest', sortOrder: 8),
  const ConstructionStep(id: '9', phase: 'bau', fotoCode: 'F09', title: 'Schwerlast-Winkel montiert (Detail)', soll: 'Je Balken 2 Winkel, 8 gesamt', sortOrder: 9),
  const ConstructionStep(id: '10', phase: 'bau', fotoCode: 'F10', title: 'Platte mit versiegelten Kanten + Entwässerungslöchern', soll: 'Kanten rundum versiegelt; Löcher Ø 8 mm', sortOrder: 10),
  const ConstructionStep(id: '11', phase: 'bau', fotoCode: 'F11', title: 'Alle 4 Platten montiert (Gesamtansicht)', soll: 'Völkerabstand ≈ 265 mm, Plattenlücke ~160 mm', sortOrder: 11),
  const ConstructionStep(id: '12', phase: 'bau', fotoCode: 'F12', title: 'Wasserwaage auf einer Platte', soll: 'Jede Platte waagerecht (Waagengenauigkeit)', sortOrder: 12),
  const ConstructionStep(id: '13', phase: 'bau', fotoCode: 'F13', title: 'Fertig behandelter, getrockneter Stand', soll: 'Kein blankes Hirnholz', sortOrder: 13),
  const ConstructionStep(id: '14', phase: 'bau', fotoCode: 'F14', title: 'Waage auf Platte (vor Beute)', soll: 'Reihenfolge Platte → Waage → Beute', sortOrder: 14),
  const ConstructionStep(id: '15', phase: 'bau', fotoCode: 'F15', title: 'Fertiger Stand mit 4 Beuten, Fluglöcher Südost', soll: 'Beutenboden ≈ 44 cm', sortOrder: 15),
  const ConstructionStep(id: '16', phase: 'abnahme', fotoCode: 'F16', title: 'Übersicht Endzustand', soll: 'Keine Durchbiegung sichtbar (< 0,5 mm bei Vollvolk)', sortOrder: 16),
  const ConstructionStep(id: '17', phase: 'abnahme', fotoCode: 'F17', title: 'Detail Nivellierung/Kontermutter (Abnahme-Beleg)', soll: 'Kontermuttern fest', sortOrder: 17),
  const ConstructionStep(id: '18', phase: 'nachkontrolle', fotoCode: 'F18', title: 'Nach dem Nachnivellieren (Datum im Dateinamen)', soll: 'Wieder exakt waagerecht; keine losen Verbindungen', sortOrder: 18),
];
