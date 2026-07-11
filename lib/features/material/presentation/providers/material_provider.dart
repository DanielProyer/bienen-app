import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';

final materialListProvider =
    AsyncNotifierProvider<MaterialListNotifier, List<MaterialItem>>(
        MaterialListNotifier.new);

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedPhaseProvider = StateProvider<int?>((ref) => null);
final selectedBereichProvider = StateProvider<String?>((ref) => null);

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

/// Items für den Umschalter „Einkaufen": Status geplant/bestellt,
/// gefiltert nach Bereich (null = alle) und Phase (null = alle).
final einkaufenItemsProvider = Provider<List<MaterialItem>>((ref) {
  final items = ref.watch(materialListProvider).valueOrNull ?? [];
  final bereich = ref.watch(selectedBereichProvider);
  final phase = ref.watch(selectedPhaseProvider);
  return items.where((i) {
    if (i.status != 'geplant' && i.status != 'bestellt') return false;
    if (bereich != null && i.bereich != bereich) return false;
    if (phase != null && i.phase != phase) return false;
    return true;
  }).toList();
});

/// Items für den Umschalter „Bestand": Status gekauft,
/// gefiltert nach Bereich (null = alle).
final bestandItemsProvider = Provider<List<MaterialItem>>((ref) {
  final items = ref.watch(materialListProvider).valueOrNull ?? [];
  final bereich = ref.watch(selectedBereichProvider);
  return items.where((i) {
    if (i.status != 'gekauft') return false;
    if (bereich != null && i.bereich != bereich) return false;
    return true;
  }).toList();
});

/// Verbrauchsmaterial im Bestand (gekauft), das unter den Mindestbestand
/// gefallen ist – die eigentliche Nachkauf-Warnung. Noch nie gekaufte
/// (geplante) Verbrauchsartikel stehen in „Einkaufen", nicht hier.
final nachkaufenItemsProvider = Provider<List<MaterialItem>>((ref) {
  final items = ref.watch(materialListProvider).valueOrNull ?? [];
  return items
      .where((i) =>
          i.isConsumable && i.status == 'gekauft' && i.stockQty < i.minQty)
      .toList();
});

final nachkaufenCountProvider = Provider<int>((ref) {
  return ref.watch(nachkaufenItemsProvider).length;
});

final materialPurchasesProvider =
    AsyncNotifierProvider<MaterialPurchasesNotifier, List<MaterialPurchase>>(
        MaterialPurchasesNotifier.new);

/// Käufe gruppiert nach materialId.
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

  Future<List<MaterialPurchase>> _fetch() async {
    try {
      final response = await SupabaseConfig.client
          .from('material_purchases')
          .select()
          .order('gekauft_am', ascending: false);
      return (response as List)
          .map((j) => MaterialPurchase.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPurchase(MaterialPurchase p) async {
    final json = p.toJson();
    json.remove('id'); // let Supabase generate the UUID
    await SupabaseConfig.client.from('material_purchases').insert(json);
    ref.invalidateSelf();
  }

  Future<void> deletePurchase(String id) async {
    await SupabaseConfig.client
        .from('material_purchases')
        .delete()
        .eq('id', id);
    ref.invalidateSelf();
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

  Future<List<MaterialItem>> _fetchFromSupabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('materials')
          .select()
          .order('sort_order', ascending: true);
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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchFromSupabase());
  }
}

// Fallback seed data (Imkerhof-Einkaufsliste Herbst 2026 -> Frühling 2027, 2 Dadant-10er)
final _seedData = [
  const MaterialItem(id: '1', category: 'Beute', name: 'Dadant Blatt Magazin 10er, komplett', description: 'Schweizer Fichte Massivholz 24 mm, wasserfest, Knuchel-Anstrich, Chromstahl-Schienen. Enthält Boden+Schieber+Fluglochkeil, Brutraum, 2 Honigräume, Absperrgitter, Bienenflucht, isol. Innendeckel, Chromstahldeckel, Schied.', quantity: 2, unit: 'Stk', priceCHF: 465.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://www.imkerhof.ch/index.php/magazine/product/dadant-blatt.html', phase: 1, status: 'geplant', sortOrder: 1, notes: 'Preis vor Bestellung bestätigen (081 284 66 77). Prüfen, ob Rähmchen enthalten sind – falls ja, Rähmchen-Menge reduzieren.'),
  const MaterialItem(id: '2', category: 'Beute', name: 'Honigraumzarge Dadant Blatt 10er (Reserve)', description: 'Fichte 24 mm, Chromstahl 9er-Rechen, fingerverzinkt. Reserve für starke Volksentwicklung.', quantity: 2, unit: 'Stk', priceCHF: 72.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/beutesysteme/dadant-blatt-1/dadant-blatt-magazin-honigraumzarge-10er/', phase: 2, status: 'geplant', sortOrder: 2, notes: 'Optional/später – Beute bringt bereits 2 Honigräume je Volk mit.'),
  const MaterialItem(id: '3', category: 'Rahmenbau', name: 'Brutrahmen Dadant Blatt Hoffmann (gedrahtet)', description: 'Linde, fertig gedrahtet mit Chromstahldraht, sofort einsatzbereit. Mittelwände selbst einlöten.', quantity: 30, unit: 'Stk', priceCHF: 3.65, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/wabenbau-rahmen/rahmen-1/brutrahmen-dadant-blatt/', phase: 1, status: 'geplant', sortOrder: 10, notes: 'Menge für 2 Völker + Reserve/Nachzucht. Falls Beute Rähmchen enthält, reduzieren.'),
  const MaterialItem(id: '4', category: 'Rahmenbau', name: 'Honigrahmen Dadant Blatt (gedrahtet)', description: 'Linde, mit Chromstahldraht verstärkt, fertig gedrahtet.', quantity: 40, unit: 'Stk', priceCHF: 3.45, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/wabenbau-rahmen/rahmen-1/honigrahmen-dadant-blatt/', phase: 1, status: 'geplant', sortOrder: 11, notes: 'Menge für 2 Völker + Reserve. Falls Beute Rähmchen enthält, reduzieren.'),
  const MaterialItem(id: '5', category: 'Rahmenbau', name: 'Drahteinschmelzer umschaltbar', description: 'Einlöttrafo für Chromstahl- UND verzinnten Draht (zukunftssicher). Zum Einlöten der Mittelwände.', quantity: 1, unit: 'Stk', priceCHF: 139.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/wabenbau-rahmen/', phase: 1, status: 'geplant', sortOrder: 12, notes: 'Imkerhof-Rähmchen sind bereits gedrahtet – nur Mittelwände einlöten. Echtes Selber-Drahten/Bausätze gäbe es bei imkereiausruester.ch.'),
  const MaterialItem(id: '6', category: 'Rahmenbau', name: 'BIO Mittelwände Dadant Brutraum', description: 'Reines Bio-Bienenwachs, rückstandsarm, 9 Blätter je kg. Passt zum Bio-Honig-Ziel.', quantity: 4, unit: 'kg', priceCHF: 31.80, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/wabenbau-rahmen/mittelwaende/dadant-1/', phase: 1, status: 'geplant', sortOrder: 13, notes: '~4 kg für ~30 Bruträhmchen.'),
  const MaterialItem(id: '7', category: 'Rahmenbau', name: 'BIO Mittelwände Dadant Honigraum', description: 'Reines Bio-Bienenwachs, 18 Blätter je kg.', quantity: 3, unit: 'kg', priceCHF: 31.80, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/wabenbau-rahmen/mittelwaende/dadant-1/bio-dadant-blatt-honigwaben/', phase: 1, status: 'geplant', sortOrder: 14, notes: '~3 kg für ~40 Honigrähmchen.'),
  const MaterialItem(id: '8', category: 'Varroa', name: 'Ameisensäure Formivar 60 % (1 L)', description: 'ad us. vet. (Andermatt BioVet). Spätsommer-Langzeitbehandlung, wirkt in die verdeckelte Brut.', quantity: 1, unit: 'Flasche', priceCHF: 21.30, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/ameisensaeurebehandlung-1/formivar/', phase: 1, status: 'geplant', sortOrder: 20, notes: '1 L reicht für die Herbstbehandlung; ab 2 Völkern jährlich ~2 L.'),
  const MaterialItem(id: '9', category: 'Varroa', name: 'Nassenheider Professional Verdunster (Set)', description: 'Hochwertiger Langzeitverdunster, passt sich Temperatur/Feuchte an. Set = 2 Verdunster (beide Völker).', quantity: 1, unit: 'Set', priceCHF: 33.80, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/ameisensaeurebehandlung-1/nassenheider-professional/', phase: 1, status: 'geplant', sortOrder: 21),
  const MaterialItem(id: '10', category: 'Varroa', name: 'Oxalsäure Oxuvar 5.7 % (275 ml)', description: 'Für die brutfreie Winter-Träufelbehandlung (mit Zucker 1:1). 275 ml reichen für 2 Völker.', quantity: 1, unit: 'Flasche', priceCHF: 19.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/oxalsaeurebehandlung-1/oxuvar-5-7/', phase: 1, status: 'geplant', sortOrder: 22, notes: 'Winterbehandlung (Dez/Jan, brutfrei), Träufeln.'),
  const MaterialItem(id: '11', category: 'Varroa', name: 'Automatikspritze (Oxalsäure träufeln)', description: 'Passt auf Oxuvar-Flasche, Dosis 1–5 ml, abgewinkelte Nadel – keine Überdosierung, ideal für Anfänger.', quantity: 1, unit: 'Stk', priceCHF: 99.95, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/ameisensaeurebehandlung-1/automatikspritze/', phase: 1, status: 'geplant', sortOrder: 23, notes: 'Komfort-/Qualitätslösung. Günstige Alternative: einfache 10–20-ml-Dosierspritze.'),
  const MaterialItem(id: '12', category: 'Varroa', name: 'Varroa Alu-Lochgitter (Diagnose)', description: 'Diagnosegitter auf die Bodeneinlage – korrekte Milbenzählung. 29,7 × 48,5 cm.', quantity: 2, unit: 'Stk', priceCHF: 24.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/weiteres/varroa-alu-lochgitter/', phase: 1, status: 'geplant', sortOrder: 24),
  const MaterialItem(id: '13', category: 'Varroa', name: 'Säurefeste Schutzhandschuhe', description: 'Chemikalienschutz Kat. III (Neopren/Latex), lebensmitteltauglich.', quantity: 1, unit: 'Paar', priceCHF: 25.75, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/schutzmassnahmen-1/schutzhandschuhe-saeurefest/', phase: 1, status: 'geplant', sortOrder: 25, notes: 'Pflicht bei Säurearbeit.'),
  const MaterialItem(id: '14', category: 'Varroa', name: 'Schutzbrille 3M', description: 'Vollsicht, mit Halbmaske kombinierbar, über Korrekturbrille tragbar.', quantity: 1, unit: 'Stk', priceCHF: 39.95, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/schutzmassnahmen-1/schutzbrille-3m/', phase: 1, status: 'geplant', sortOrder: 26),
  const MaterialItem(id: '15', category: 'Varroa', name: 'Atemschutz Halbmaske (Säure)', description: 'Wiederverwendbare 3M-Halbmaske für die Säurebehandlung.', quantity: 1, unit: 'Set', priceCHF: 135.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/schutzmassnahmen-1/starterkit-halbmaske-3m-groesse-m/', phase: 1, status: 'geplant', sortOrder: 27, notes: 'WICHTIG: passenden Säure-/FFP3-Filter wählen, NICHT den mitgelieferten A2-Filter. Filter mit Imkerhof klären. Günstige Alternative: FFP3-Einwegmaske.'),
  const MaterialItem(id: '16', category: 'Varroa', name: 'Thymovar (Thymol, 2 Plättchen)', description: 'Königin-/brutschonend. Auf 1570 m im Herbst oft zu kalt (braucht 20–25 °C) – nur Ergänzung.', quantity: 2, unit: 'Pack', priceCHF: 11.45, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/behandlung-reinigung/weiteres/thymovar-2-plaettchen/', phase: 2, status: 'geplant', sortOrder: 28, notes: 'Optional – Ameisensäure priorisieren.'),
  const MaterialItem(id: '17', category: 'Fütterung', name: 'Bio Hostettler Futtersirup 20 kg', description: 'Invertzuckersirup + Bio-Zucker, 72–73 % Zucker, Bag mit Ausguss. Passt zum Bio-Ziel.', quantity: 1, unit: 'Bag', priceCHF: 61.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/fuetterung/futter-1/bio-hostettler-futtersirup-20-kg/', phase: 1, status: 'geplant', sortOrder: 30, notes: 'Herbstauffütterung 1 Volk (~18–20 kg auf 1570 m). 2. Volk/Frühling separat. Günstiger (nicht Bio): Apiinvert 28 kg CHF 51.80.'),
  const MaterialItem(id: '18', category: 'Fütterung', name: 'Apifonda Futterteig 2,5 kg', description: 'Gebrauchsfertiger Teig für Frühjahrsstimulation/Notfütterung.', quantity: 2, unit: 'Beutel', priceCHF: 8.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/fuetterung/futter-1/apifonda-2-5-kg-futterteig/', phase: 1, status: 'geplant', sortOrder: 31),
  const MaterialItem(id: '19', category: 'Fütterung', name: 'Futtertasche Dadant Blatt 3 L', description: 'Kunststoff, direkt an die Traube hängbar, passt exakt Dadant Blatt.', quantity: 2, unit: 'Stk', priceCHF: 18.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/fuetterung/futtergeschirr-1/futtertasche-dadant-blatt-kunststoff/', phase: 1, status: 'geplant', sortOrder: 32, notes: 'Nur falls kein Futtergeschirr in der Beute. Für 20 kg mehrfach nachfüllen – grösserer Aufsetzfütterer (7–10 L) ist komfortabler.'),
  const MaterialItem(id: '20', category: 'Werkzeug', name: 'Stockmeissel handgeschmiedet', description: 'Handgeschmiedet, sehr langlebig (hält ein Leben lang).', quantity: 2, unit: 'Stk', priceCHF: 36.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/werkzeuge-rauch/werkzeug-1/stockmeissel-handgeschmiedet/', phase: 1, status: 'geplant', sortOrder: 40, notes: 'Je 1 für Daniel + Lorena.'),
  const MaterialItem(id: '21', category: 'Werkzeug', name: 'Wabenzange VSI', description: 'Handgeschmiedeter Rähmchengreifer, 27 cm, präzises/sicheres Arbeiten.', quantity: 1, unit: 'Stk', priceCHF: 76.50, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/werkzeuge-rauch/werkzeug-1/wabenzange-vsi/', phase: 1, status: 'geplant', sortOrder: 41),
  const MaterialItem(id: '22', category: 'Werkzeug', name: 'Bienenbürste gebogen', description: 'Ergonomische, gebogene Abkehrbürste.', quantity: 2, unit: 'Stk', priceCHF: 16.40, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/werkzeuge-rauch/werkzeug-1/bienenbuerste-gebogen/', phase: 1, status: 'geplant', sortOrder: 42, notes: 'Sprühflasche + Stockkarten: Haushaltsartikel bzw. digitale App – nicht bei Imkerhof.'),
  const MaterialItem(id: '23', category: 'Überwinterung', name: 'Bienenkissen Schafwolle Dadant', description: 'Natürliche Schafwoll-Dämmung auf die Wintertraube – ideal für harte Höhen-Winter.', quantity: 2, unit: 'Stk', priceCHF: 11.80, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/beutesysteme/dadant-blatt-1/bienenkissen-schafwolle-dadant/', phase: 1, status: 'geplant', sortOrder: 50),
  const MaterialItem(id: '24', category: 'Überwinterung', name: 'Schaumstoffstreifen Flugloch', description: 'Zuschneidbare Fluglochverengung (weich, bienenschonend). Fluglochkeil ist zusätzlich in der Beute.', quantity: 2, unit: 'Stk', priceCHF: 2.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/beutesysteme/zubehoer-beutesysteme-1/schaumstoffstreifen-fuer-flugloch/', phase: 1, status: 'geplant', sortOrder: 51),
  const MaterialItem(id: '25', category: 'Überwinterung', name: 'Buch „Einfach imkern" (Dr. G. Liebig)', description: 'Evidenzbasiertes Einsteiger-Standardwerk, starker Teil zu organischen Säuren/Varroa.', quantity: 1, unit: 'Stk', priceCHF: 32.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/literatur-spiele/grundwissen-1/einfach-imkern/', phase: 1, status: 'geplant', sortOrder: 52),
  const MaterialItem(id: '26', category: 'Monitoring', name: 'HiveWatch Stockwaage (Volk 1)', description: 'Digitale Stockwaage 500×430, 4G/LTE-M (in Arosa gesichert), Gewicht+Temp+Feuchte. Winter-Futterkontrolle auf 1570 m sehr wertvoll.', quantity: 1, unit: 'Stk', priceCHF: 694.00, supplier: 'Bienen Meier / hivewatch.ch', supplierUrl: 'https://www.hivewatch.ch', phase: 1, status: 'geplant', sortOrder: 60, notes: 'Nicht Imkerhof. Herbst 2026 für Daniels Volk. Abo ~CHF 8/Mt. Preis bei hivewatch.ch bestätigen. Stand ist auf diese Waage ausgelegt.'),
  const MaterialItem(id: '27', category: 'Monitoring', name: 'HiveWatch Stockwaage (Volk 2)', description: '2. Waage für Lorenas Volk (Frühling 2027).', quantity: 1, unit: 'Stk', priceCHF: 694.00, supplier: 'Bienen Meier / hivewatch.ch', supplierUrl: 'https://www.hivewatch.ch', phase: 2, status: 'geplant', sortOrder: 61, notes: 'Frühling 2027.'),
  const MaterialItem(id: '28', category: 'Nachzucht', name: 'Ablegermagazin Dadant Blatt', description: 'Für 6 Dadant-Rahmen. Schweizer Fichte 24 mm, fingerverzinkt, Chromstahl. Enthält Boden, Brutraum, 2 Honigräume, Bienenflucht, Innendeckel, Chromstahldeckel.', quantity: 2, unit: 'Stk', priceCHF: 359.00, supplier: 'Imkerhof Maienfeld', supplierUrl: 'https://imkerhof.ch/produkte/beutesysteme/ablegerkasten-1/ablegermagazin-dadant-blatt/', phase: 2, status: 'geplant', sortOrder: 70, notes: 'Für die 1–2 Nachzucht-Völker Sommer 2027 – jetzt kaufen und bereit haben.'),
];
