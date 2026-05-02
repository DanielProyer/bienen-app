import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:intl/intl.dart';

class MaterialListTile extends ConsumerWidget {
  final MaterialItem item;

  const MaterialListTile({super.key, required this.item});

  Color _statusColor(String status) {
    switch (status) {
      case 'bestellt':
        return AppColors.amber600;
      case 'geliefert':
        return AppColors.green600;
      default:
        return AppColors.brown300;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'bestellt':
        return Icons.local_shipping;
      case 'geliefert':
        return Icons.check_circle;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status button
            PopupMenuButton<String>(
              onSelected: (newStatus) {
                ref
                    .read(materialListProvider.notifier)
                    .updateStatus(item.id, newStatus);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'offen', child: Text('Offen')),
                const PopupMenuItem(value: 'bestellt', child: Text('Bestellt')),
                const PopupMenuItem(
                    value: 'geliefert', child: Text('Geliefert')),
              ],
              child: Icon(
                _statusIcon(item.status),
                color: _statusColor(item.status),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: item.status == 'geliefert'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.brown300),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.supplier != null)
                        Text(
                          item.supplier!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.honey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (item.supplier != null) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brown50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Phase ${item.phase}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.brown600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Quantity + Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.brown600,
                  ),
                ),
                if (item.priceCHF != null)
                  Text(
                    'CHF ${NumberFormat('#,##0.00', 'de_CH').format(item.totalPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.honeyDark,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
