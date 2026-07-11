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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Material & Lager'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
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
              const Tab(text: 'Ausgaben'),
            ],
          ),
        ),
        body: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          // Builder: Context UNTERHALB des DefaultTabController, damit
          // DefaultTabController.of(...) den Controller findet.
          data: (_) => Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  // Bereich-Filter im Ausgaben-Tab (Index 3) ausblenden –
                  // dort wird stets die globale Übersicht gezeigt.
                  final showFilter = tabController.index != 3;
                  return Column(
                    children: [
                      if (showFilter) const _BereichFilterRow(),
                      const Expanded(
                        child: TabBarView(
                          children: [
                            _EinkaufenView(),
                            _BestandView(),
                            _NachkaufenView(),
                            _AusgabenView(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
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

// ---------------------------------------------------------------------------
// Ausgaben: globale Übersicht (Bereich-Filter ignoriert)
// ---------------------------------------------------------------------------
class _AusgabenView extends ConsumerWidget {
  const _AusgabenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(ausgabenUebersichtProvider);

    if (u.bisher == 0 && u.geplant == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch keine Käufe erfasst.',
            style: TextStyle(color: AppColors.brown600),
          ),
        ),
      );
    }

    // Alle vorkommenden Bereiche (aus bisher + geplant), stabil sortiert.
    final bereiche = <String>{
      ...u.bereichBisher.keys,
      ...u.bereichGeplant.keys,
    }.toList()
      ..sort((a, b) {
        final order = _bereichLabels.keys.toList();
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Drei Kennzahl-Karten
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Bisher ausgegeben',
                value: u.bisher,
                color: AppColors.green600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Geplant (offen)',
                value: u.geplant,
                color: AppColors.amber600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Gesamt',
                value: u.gesamt,
                color: AppColors.honeyDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Nach Bereich
        const Text(
          'Nach Bereich',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.brown800,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                const _BereichRow(
                  label: 'Bereich',
                  bisher: null,
                  geplant: null,
                  total: null,
                  isHeader: true,
                ),
                const Divider(height: 1),
                for (final b in bereiche)
                  _BereichRow(
                    label: _bereichLabels[b] ?? b,
                    bisher: u.bereichBisher[b] ?? 0,
                    geplant: u.bereichGeplant[b] ?? 0,
                    total: (u.bereichBisher[b] ?? 0) + (u.bereichGeplant[b] ?? 0),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Nach Zahlungsart
        const Text(
          'Nach Zahlungsart',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.brown800,
          ),
        ),
        const SizedBox(height: 8),
        if (u.proZahlungsart.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Käufe erfasst.',
              style: TextStyle(color: AppColors.brown300),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final entry in (u.proZahlungsart.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value))))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.brown800,
                              ),
                            ),
                          ),
                          Text(
                            'CHF ${_chf.format(entry.value)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.honeyDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.brown600),
            ),
            const SizedBox(height: 6),
            Text(
              'CHF ${_chf.format(value)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BereichRow extends StatelessWidget {
  final String label;
  final double? bisher;
  final double? geplant;
  final double? total;
  final bool isHeader;
  const _BereichRow({
    required this.label,
    required this.bisher,
    required this.geplant,
    required this.total,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: isHeader ? 11 : 14,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w600,
      color: isHeader ? AppColors.brown300 : AppColors.brown800,
    );
    final numStyle = TextStyle(
      fontSize: isHeader ? 11 : 13,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
      color: isHeader ? AppColors.brown300 : AppColors.brown600,
    );

    Widget cell(String text, {bool bold = false, Color? color}) => Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: bold
                ? const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.honeyDark,
                  )
                : numStyle,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: labelStyle)),
          if (isHeader) ...[
            cell('bisher'),
            cell('geplant'),
            cell('total'),
          ] else ...[
            cell('CHF ${_chf.format(bisher)}'),
            cell('CHF ${_chf.format(geplant)}'),
            cell('CHF ${_chf.format(total)}', bold: true),
          ],
        ],
      ),
    );
  }
}
