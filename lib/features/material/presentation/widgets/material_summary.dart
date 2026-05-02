import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:intl/intl.dart';

class MaterialSummary extends ConsumerWidget {
  const MaterialSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grandTotal = ref.watch(grandTotalProvider);
    final items = ref.watch(materialListProvider).valueOrNull ?? [];
    final offenCount = items.where((i) => i.status == 'offen').length;
    final bestelltCount = items.where((i) => i.status == 'bestellt').length;
    final geliefertCount = items.where((i) => i.status == 'geliefert').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.brown100)),
      ),
      child: Row(
        children: [
          _buildStatusBadge('$offenCount offen', AppColors.brown300),
          const SizedBox(width: 8),
          _buildStatusBadge('$bestelltCount bestellt', AppColors.amber600),
          const SizedBox(width: 8),
          _buildStatusBadge('$geliefertCount geliefert', AppColors.green600),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 11, color: AppColors.brown300)),
              Text(
                'CHF ${NumberFormat('#,##0.00', 'de_CH').format(grandTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.honeyDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
