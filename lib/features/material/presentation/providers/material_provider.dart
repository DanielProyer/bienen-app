import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final materialListProvider =
    AsyncNotifierProvider<MaterialListNotifier, List<MaterialItem>>(
        MaterialListNotifier.new);

// ── Reine Prädikate (testbar ohne ProviderContainer) ──────────────────────────

bool istArchiviert(MaterialItem i) => i.archiviert;
bool istVerbrauch(MaterialItem i) => !i.archiviert && i.isConsumable;
bool istAnlage(MaterialItem i) => !i.archiviert && !i.isConsumable;

/// Nachkauf-Warnung: nur aktives Verbrauchsmaterial im Bestand (gekauft),
/// mit gesetztem Mindestbestand, das darunter gefallen ist.
bool istNachzukaufen(MaterialItem i) =>
    !i.archiviert &&
    i.isConsumable &&
    i.status == 'gekauft' &&
    i.minQty > 0 &&
    i.stockQty < i.minQty;

// ── Abgeleitete Listen-Provider ───────────────────────────────────────────────

final aktiveMaterialienProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const [])
        .where((i) => !i.archiviert)
        .toList());

final verbrauchItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const [])
        .where(istVerbrauch)
        .toList());

final anlageItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const [])
        .where(istAnlage)
        .toList());

final archivItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const [])
        .where(istArchiviert)
        .toList());

/// Kosten-Dashboard über alle Materialien + Käufe; Kosten je Volk auf Basis
/// der AKTIVEN Völker (aktiveVoelkerProvider ist synchron, liefert die Liste
/// direkt).
final kostenDashboardProvider = Provider<KostenDashboard>((ref) {
  final items =
      ref.watch(materialListProvider).valueOrNull ?? const <MaterialItem>[];
  final purchases =
      ref.watch(materialPurchasesProvider).valueOrNull ?? const <MaterialPurchase>[];
  final anzahl = ref.watch(aktiveVoelkerProvider).length;
  return berechneKostenDashboard(items, purchases, anzahl);
});

/// Verbrauchsmaterial im Bestand (gekauft), das unter den Mindestbestand
/// gefallen ist – die eigentliche Nachkauf-Warnung. Noch nie gekaufte
/// (geplante) Verbrauchsartikel stehen auf der Einkaufsliste, nicht hier.
final nachkaufenItemsProvider = Provider<List<MaterialItem>>((ref) {
  final items = ref.watch(materialListProvider).valueOrNull ?? [];
  return items.where(istNachzukaufen).toList();
});

final nachkaufenCountProvider = Provider<int>((ref) {
  return ref.watch(nachkaufenItemsProvider).length;
});

final materialPurchasesProvider =
    AsyncNotifierProvider<MaterialPurchasesNotifier, List<MaterialPurchase>>(
        MaterialPurchasesNotifier.new);

/// Käufe gruppiert nach materialId (neueste zuerst, da der Fetch nach
/// gekauft_am absteigend sortiert).
final purchasesByMaterialProvider =
    Provider<Map<String, List<MaterialPurchase>>>((ref) {
  final purchases = ref.watch(materialPurchasesProvider).valueOrNull ?? [];
  final map = <String, List<MaterialPurchase>>{};
  for (final p in purchases) {
    (map[p.materialId] ??= []).add(p);
  }
  return map;
});

class MaterialPurchasesNotifier extends AsyncNotifier<List<MaterialPurchase>> {
  @override
  Future<List<MaterialPurchase>> build() => _fetch();

  /// Fehler NICHT schlucken: ein leeres Ergebnis bei Auth-/RLS-Fehlern sieht
  /// aus wie "keine Kaeufe" und maskiert das Problem. -> AsyncError an die UI.
  Future<List<MaterialPurchase>> _fetch() async {
    final response = await SupabaseConfig.client
        .from('material_purchases')
        .select()
        .order('gekauft_am', ascending: false);
    return (response as List)
        .map((j) => MaterialPurchase.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addPurchase(MaterialPurchase p) async {
    final json = p.toJson();
    json.remove('id'); // let Supabase generate the UUID
    await SupabaseConfig.client.from('material_purchases').insert(json);
    ref.invalidateSelf();
    // DB-Trigger hat stock_qty serverseitig angepasst -> Liste neu laden.
    ref.invalidate(materialListProvider);
  }

  Future<void> deletePurchase(String id) async {
    await SupabaseConfig.client
        .from('material_purchases')
        .delete()
        .eq('id', id);
    ref.invalidateSelf();
    // DB-Trigger hat stock_qty serverseitig angepasst -> Liste neu laden.
    ref.invalidate(materialListProvider);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}

class MaterialListNotifier extends AsyncNotifier<List<MaterialItem>> {
  @override
  Future<List<MaterialItem>> build() async {
    return _fetchFromSupabase();
  }

  /// Kein Auto-Seed und kein stiller _seedData-Fallback mehr:
  /// - RLS liefert bei fehlendem Zugriff 0 ZEILEN statt eines Fehlers. Das
  ///   frueher als "DB leer" zu deuten und Arosas Einkaufsliste zu seeden,
  ///   haette jedem kuenftigen Mandanten Arosa-Daten untergeschoben.
  /// - Der catch-Zweig lieferte still _seedData und maskierte damit Auth-/
  ///   RLS-Fehler. Fehler gehen jetzt als AsyncError an die UI (Retry).
  /// Erstbefuellung passiert ausschliesslich ueber den Bootstrap (Plan 3).
  Future<List<MaterialItem>> _fetchFromSupabase() async {
    final response = await SupabaseConfig.client
        .from('materials')
        .select()
        .order('sort_order', ascending: true);
    return (response as List)
        .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    // Optimistic update
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(status: newStatus) else item,
    ]);

    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'status': newStatus}).eq('id', id);
    } catch (e) {
      // Revert on failure
      state = AsyncData(current);
    }
  }

  Future<void> updateStock(String id, double qty) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(stockQty: qty) else item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'stock_qty': qty}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> setArchiviert(String id, bool wert) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(archiviert: wert) else item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'archiviert': wert}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateIsConsumable(String id, bool wert) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(isConsumable: wert) else item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'is_consumable': wert}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateMinQty(String id, double qty) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(minQty: qty) else item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'min_qty': qty}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updatePhotoUrls(String id, List<String> urls) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(photoUrls: urls) else item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'photo_urls': urls}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updatePdfs(
      String id, List<String> urls, List<String> names) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id)
          item.copyWith(pdfUrls: urls, pdfNames: names)
        else
          item,
    ]);
    try {
      await SupabaseConfig.client
          .from('materials')
          .update({'pdf_urls': urls, 'pdf_names': names}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchFromSupabase());
  }
}
