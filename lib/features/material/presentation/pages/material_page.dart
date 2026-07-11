import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/presentation/pages/material_detail_page.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_summary.dart';
import 'package:intl/intl.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
final _qty = NumberFormat('#,##0.##', 'de_CH');

const _bereichLabels = {
  'imkerei': 'Imkerei',
  'standbau': 'Standbau',
  'honigverarbeitung': 'Honigverarbeitung',
};

class MaterialPage extends ConsumerWidget {
  const MaterialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialListProvider);
    final nachkaufenCount = ref.watch(nachkaufenCountProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Material & Lager'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.amber400,
            tabs: [
              const Tab(text: 'Einkaufen'),
              const Tab(text: 'Bestand'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nachkaufen'),
                    if (nachkaufenCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$nachkaufenCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brown800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (_) => Column(
            children: const [
              _BereichFilterRow(),
              Expanded(
                child: TabBarView(
                  children: [
                    _EinkaufenView(),
                    _BestandView(),
                    _NachkaufenView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BereichFilterRow extends ConsumerWidget {
  const _BereichFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBereichProvider);

    Widget chip(String label, String? value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) =>
                ref.read(selectedBereichProvider.notifier).state = value,
          ),
        );

    return Container(
      width: double.infinity,
      color: AppColors.amber50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Alle', null),
            chip('Imkerei', 'imkerei'),
            chip('Standbau', 'standbau'),
            chip('Honigverarbeitung', 'honigverarbeitung'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Einkaufen: nach Kategorie gruppiert mit Summen + Summary-Leiste oben
// ---------------------------------------------------------------------------
class _EinkaufenView extends ConsumerWidget {
  const _EinkaufenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(einkaufenItemsProvider);

    final grouped = <String, List<MaterialItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      children: [
        const MaterialSummary(),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nichts zu kaufen – alles erledigt ✓',
                      style: TextStyle(color: AppColors.brown600),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final category = grouped.keys.elementAt(index);
                    final categoryItems = grouped[category]!;
                    final categoryTotal = categoryItems.fold<double>(
                        0, (sum, item) => sum + item.totalPrice);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.brown800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'CHF ${_chf.format(categoryTotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.honeyDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...categoryItems
                            .map((item) => MaterialListTile(item: item)),
                        const Divider(height: 24),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bestand: nach Bereich -> Kategorie gruppiert
// ---------------------------------------------------------------------------
class _BestandView extends ConsumerWidget {
  const _BestandView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bestandItemsProvider);

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch nichts im Bestand.',
            style: TextStyle(color: AppColors.brown600),
          ),
        ),
      );
    }

    // Bereich -> Kategorie -> Items
    final byBereich = <String, Map<String, List<MaterialItem>>>{};
    for (final item in items) {
      byBereich
          .putIfAbsent(item.bereich, () => {})
          .putIfAbsent(item.category, () => [])
          .add(item);
    }

    final bereiche = byBereich.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bereiche.length,
      itemBuilder: (context, index) {
        final bereich = bereiche[index];
        final categories = byBereich[bereich]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _bereichLabels[bereich] ?? bereich,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.honeyDark,
                ),
              ),
            ),
            for (final entry in categories.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.brown800,
                  ),
                ),
              ),
              ...entry.value.map((item) => _BestandTile(item: item)),
              const SizedBox(height: 8),
            ],
            const Divider(height: 24),
          ],
        );
      },
    );
  }
}

class _BestandTile extends ConsumerWidget {
  final MaterialItem item;
  const _BestandTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!item.isConsumable) {
      return MaterialListTile(item: item);
    }

    final purchases = ref.watch(purchasesByMaterialProvider)[item.id] ?? [];
    final lastPurchase = purchases.isNotEmpty ? purchases.first : null;
    final low = item.stockQty < item.minQty;

    return MaterialListTile(
      item: item,
      extraInfo: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  low ? Icons.warning_amber : Icons.inventory_2_outlined,
                  size: 15,
                  color: low ? Colors.red.shade600 : AppColors.brown600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bestand ${_qty.format(item.stockQty)} / min ${_qty.format(item.minQty)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: low ? Colors.red.shade600 : AppColors.brown600,
                  ),
                ),
              ],
            ),
            if (lastPurchase != null) ...[
              const SizedBox(height: 3),
              Text(
                _lastPurchaseLabel(lastPurchase),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.brown300),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _lastPurchaseLabel(MaterialPurchase p) {
    final parts = <String>[];
    if (p.gekauftAm != null) {
      parts.add(DateFormat('dd.MM.yyyy').format(p.gekauftAm!));
    }
    if (p.shop != null && p.shop!.isNotEmpty) parts.add(p.shop!);
    if (p.gesamtpreis != null) {
      parts.add('CHF ${_chf.format(p.gesamtpreis)}');
    }
    return 'Letzter Kauf: ${parts.join(' · ')}';
  }
}

// ---------------------------------------------------------------------------
// Nachkaufen: prominente amber Karten
// ---------------------------------------------------------------------------
class _NachkaufenView extends ConsumerWidget {
  const _NachkaufenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(nachkaufenItemsProvider);

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Alles ausreichend im Bestand ✓',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.green800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.amber50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.honey, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MaterialDetailPage(item: item),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.amber800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.brown800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bestand ${_qty.format(item.stockQty)} / Mindest ${_qty.format(item.minQty)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.honey,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Auf Einkaufen setzen'),
                      onPressed: () => ref
                          .read(materialListProvider.notifier)
                          .updateStatus(item.id, 'geplant'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
