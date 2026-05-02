import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_summary.dart';
import 'package:intl/intl.dart';

class MaterialPage extends ConsumerWidget {
  const MaterialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredMaterialProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedPhase = ref.watch(selectedPhaseProvider);
    final allItems = ref.watch(materialListProvider);

    final categories = allItems.map((i) => i.category).toSet().toList();

    // Group by category
    final grouped = <String, List<dynamic>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Materialliste')),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.amber50,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Alle'),
                        selected: selectedCategory == null,
                        onSelected: (_) => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 8),
                      ...categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              onSelected: (_) => ref
                                  .read(selectedCategoryProvider.notifier)
                                  .state = selectedCategory == cat ? null : cat,
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Alle Phasen'),
                        selected: selectedPhase == null,
                        onSelected: (_) => ref
                            .read(selectedPhaseProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 8),
                      for (int i = 1; i <= 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('Phase $i'),
                            selected: selectedPhase == i,
                            onSelected: (_) => ref
                                .read(selectedPhaseProvider.notifier)
                                .state = selectedPhase == i ? null : i,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Summary
          const MaterialSummary(),
          // List
          Expanded(
            child: ListView.builder(
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
                            'CHF ${NumberFormat('#,##0.00', 'de_CH').format(categoryTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.honeyDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...categoryItems.map((item) => MaterialListTile(item: item)),
                    const Divider(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
