import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';

final materialListProvider =
    AsyncNotifierProvider<MaterialListNotifier, List<MaterialItem>>(
        MaterialListNotifier.new);

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedPhaseProvider = StateProvider<int?>((ref) => null);

final filteredMaterialProvider = Provider<List<MaterialItem>>((ref) {
  final itemsAsync = ref.watch(materialListProvider);
  final items = itemsAsync.valueOrNull ?? [];
  final category = ref.watch(selectedCategoryProvider);
  final phase = ref.watch(selectedPhaseProvider);

  var filtered = items;
  if (category != null) {
    filtered = filtered.where((i) => i.category == category).toList();
  }
  if (phase != null) {
    filtered = filtered.where((i) => i.phase == phase).toList();
  }
  return filtered;
});

final categoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final itemsAsync = ref.watch(materialListProvider);
  final items = itemsAsync.valueOrNull ?? [];
  final totals = <String, double>{};
  for (final item in items) {
    totals[item.category] = (totals[item.category] ?? 0) + item.totalPrice;
  }
  return totals;
});

final grandTotalProvider = Provider<double>((ref) {
  final itemsAsync = ref.watch(materialListProvider);
  final items = itemsAsync.valueOrNull ?? [];
  return items.fold(0.0, (sum, item) => sum + item.totalPrice);
});

class MaterialListNotifier extends AsyncNotifier<List<MaterialItem>> {
  @override
  Future<List<MaterialItem>> build() async {
    return _fetchFromSupabase();
  }

  Future<List<MaterialItem>> _fetchFromSupabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('materials')
          .select()
          .order('sort_order');
      final items = (response as List)
          .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
          .toList();
      if (items.isEmpty) {
        // DB is empty, seed it
        await _seedDatabase();
        return _fetchFromSupabase();
      }
      return items;
    } catch (e) {
      // Fallback to local data if Supabase is unreachable
      return _seedData;
    }
  }

  Future<void> _seedDatabase() async {
    final rows = _seedData.map((item) {
      final json = item.toJson();
      json.remove('id'); // let Supabase generate UUIDs
      return json;
    }).toList();
    await SupabaseConfig.client.from('materials').insert(rows);
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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchFromSupabase());
  }
}

// Fallback seed data
final _seedData = [
  const MaterialItem(id: '1', category: 'Beute', name: 'Komplettbeute DB Halbzargen Hochboden', description: 'Inkl. Blechdeckel, Brutzarge, 2 Honighalbzargen, Hochboden, Absperrgitter', quantity: 2, unit: 'Stk', priceCHF: 469.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 1),
  const MaterialItem(id: '2', category: 'Beute', name: 'Zusätzliche Honighalbzargen DB', description: 'Reserve/Erweiterung', quantity: 2, unit: 'Stk', priceCHF: 40.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 2),
  const MaterialItem(id: '3', category: 'Beute', name: 'Futtertrog Nicot DB', description: 'Kunststoff-Fütterer', quantity: 2, unit: 'Stk', priceCHF: 25.00, supplier: 'bienenbeuten.ch', supplierUrl: 'https://www.bienenbeuten.ch', phase: 1, status: 'offen', sortOrder: 3),
  const MaterialItem(id: '4', category: 'Beute', name: 'Rähmchen Brut DB (Hoffmann)', description: 'Gedrahtet, Reserve', quantity: 20, unit: 'Stk', priceCHF: 2.10, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 4),
  const MaterialItem(id: '5', category: 'Beute', name: 'Rähmchen Honig DB Halbrahmen', description: 'Reserve', quantity: 20, unit: 'Stk', priceCHF: 1.80, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 5),
  const MaterialItem(id: '6', category: 'Beute', name: 'Mittelwände DB Brutraum', quantity: 2, unit: 'kg', priceCHF: 24.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 6),
  const MaterialItem(id: '7', category: 'Beute', name: 'Mittelwände DB Honigraum', quantity: 2, unit: 'kg', priceCHF: 24.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 7),
  const MaterialItem(id: '8', category: 'Schutz', name: 'Imkerjacke mit Schleier', description: 'Baumwolle/Mesh mit abnehmbarem Rundschleier', quantity: 2, unit: 'Stk', priceCHF: 107.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 10),
  const MaterialItem(id: '9', category: 'Schutz', name: 'Imkerhandschuhe Leder', description: 'Schafleder mit Stulpe', quantity: 2, unit: 'Paar', priceCHF: 17.60, supplier: 'imkereiausruester.ch', supplierUrl: 'https://www.imkereiausruester.ch', phase: 1, status: 'offen', sortOrder: 11),
  const MaterialItem(id: '10', category: 'Werkzeug', name: 'Stockmeissel Schweizer Modell', description: 'Maxant Easy, Edelstahl', quantity: 1, unit: 'Stk', priceCHF: 7.90, supplier: 'beetec', supplierUrl: 'https://www.beetec.ch', phase: 1, status: 'offen', sortOrder: 20),
  const MaterialItem(id: '11', category: 'Werkzeug', name: 'Smoker Dadant gross', description: 'Edelstahl, Ø10cm, Lederblag, Innenlüfter', quantity: 1, unit: 'Stk', priceCHF: 85.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 21),
  const MaterialItem(id: '12', category: 'Werkzeug', name: 'Abkehrbesen', description: 'Weiche Borsten', quantity: 1, unit: 'Stk', priceCHF: 5.90, supplier: 'beetec', supplierUrl: 'https://www.beetec.ch', phase: 1, status: 'offen', sortOrder: 22),
  const MaterialItem(id: '13', category: 'Werkzeug', name: 'Wabenzange Classic', quantity: 1, unit: 'Stk', priceCHF: 8.90, supplier: 'imkereiausruester.ch', supplierUrl: 'https://www.imkereiausruester.ch', phase: 1, status: 'offen', sortOrder: 23),
  const MaterialItem(id: '14', category: 'Werkzeug', name: 'Einlöttrafo BPS Basic', description: '12-19V, Timer-Funktion, Klemmen', quantity: 1, unit: 'Stk', priceCHF: 59.80, supplier: 'imkereiausruester.ch', supplierUrl: 'https://www.imkereiausruester.ch', phase: 1, status: 'offen', sortOrder: 24),
  const MaterialItem(id: '15', category: 'Honigverarbeitung', name: 'Honigschleuder Logar 20/8 Radial', description: '20 Halbrahmen, Motor mit Drehzahlregler, Edelstahl V2A', quantity: 1, unit: 'Stk', priceCHF: 1900.00, supplier: 'Logar Trade', supplierUrl: 'https://www.logar-trade.com', phase: 2, status: 'offen', sortOrder: 30),
  const MaterialItem(id: '16', category: 'Honigverarbeitung', name: 'Entdeckelungsgabel Edelstahl', quantity: 1, unit: 'Stk', priceCHF: 33.50, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 2, status: 'offen', sortOrder: 31),
  const MaterialItem(id: '17', category: 'Honigverarbeitung', name: 'Doppelsieb Edelstahl', description: 'Ø 240mm', quantity: 1, unit: 'Stk', priceCHF: 45.00, supplier: 'bienenbeuten.ch', supplierUrl: 'https://www.bienenbeuten.ch', phase: 2, status: 'offen', sortOrder: 32),
  const MaterialItem(id: '18', category: 'Honigverarbeitung', name: 'Abfüllbehälter Edelstahl 25kg', description: 'Mit Quetschhahn', quantity: 1, unit: 'Stk', priceCHF: 240.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 2, status: 'offen', sortOrder: 33),
  const MaterialItem(id: '19', category: 'Honigverarbeitung', name: 'Refraktometer', description: 'Wassergehalt-Messung, temperaturkompensiert, Skala 12-27%', quantity: 1, unit: 'Stk', priceCHF: 69.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 2, status: 'offen', sortOrder: 34),
  const MaterialItem(id: '20', category: 'Varroa', name: 'Nassenheider Professional Verdunster', description: 'Langzeit-Verdunster Ameisensäure, 14 Tage Behandlung', quantity: 1, unit: 'Set', priceCHF: 29.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 40),
  const MaterialItem(id: '21', category: 'Varroa', name: 'FORMIVAR 60% Ameisensäure', description: '1 Liter, Sommerbehandlung Juli-Aug', quantity: 1, unit: 'Fl', priceCHF: 30.50, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 41),
  const MaterialItem(id: '22', category: 'Varroa', name: 'Oxalsäure-Dihydrat 75g', description: 'Winterbehandlung (brutfrei, Nov-Dez)', quantity: 1, unit: 'Pkg', priceCHF: 34.50, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 42),
  const MaterialItem(id: '23', category: 'Fütterung', name: 'Futtersirup Apiinvert 16 kg', description: 'Invertierter Sirup, Bag-in-Box, Herbstauffütterung', quantity: 2, unit: 'Box', priceCHF: 27.20, supplier: 'imkereiausruester.ch', supplierUrl: 'https://www.imkereiausruester.ch', phase: 1, status: 'offen', sortOrder: 50),
  const MaterialItem(id: '24', category: 'Fütterung', name: 'Apifonda Futterteig 2.5 kg', description: 'Frühjahrsstimulation / Notfütterung', quantity: 1, unit: 'Pkg', priceCHF: 7.00, supplier: 'imkereiausruester.ch', supplierUrl: 'https://www.imkereiausruester.ch', phase: 1, status: 'offen', sortOrder: 51),
  const MaterialItem(id: '25', category: 'Sonstiges', name: 'Beutenständer Metall', description: 'Verzinkt, höhenverstellbar, kippsicher', quantity: 2, unit: 'Stk', priceCHF: 125.00, supplier: 'FAIE.ch', supplierUrl: 'https://www.faie.ch', phase: 1, status: 'offen', sortOrder: 60),
  const MaterialItem(id: '26', category: 'Sonstiges', name: 'Mäuseschutzgitter', description: 'Fluglochschutz Metall, für Wintermonate', quantity: 2, unit: 'Stk', priceCHF: 8.00, supplier: 'Wespi', supplierUrl: 'https://www.wespi-imkerei.ch', phase: 1, status: 'offen', sortOrder: 61),
  const MaterialItem(id: '27', category: 'Monitoring', name: 'Stockwaage digital', description: 'HiveWatch StarterSet, 4G/LTE-M, -35°C bis +65°C, Gewicht+Temp+Feuchte', quantity: 1, unit: 'Stk', priceCHF: 694.00, supplier: 'Bienen Meier AG', supplierUrl: 'https://www.bienen-meier.ch/de/produkt/digitale-stockwaagehivewatch-starterset', phase: 1, status: 'offen', sortOrder: 62, notes: 'HiveWatch: Schweizer Produkt, 4G garantiert in Arosa. Abo CHF 8.-/Monat.'),
];
