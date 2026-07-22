import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_alternatives.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/pages/material_detail_page.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:intl/intl.dart';

class MaterialListTile extends ConsumerWidget {
  final MaterialItem item;

  /// Optionaler Zusatzinhalt (z.B. Bestand/letzter Kauf in der Bestand-Ansicht).
  final Widget? extraInfo;

  const MaterialListTile({super.key, required this.item, this.extraInfo});

  Color _statusColor(String status) {
    switch (status) {
      case 'bestellt':
        return BeeSignal.warnung.text;
      case 'gekauft':
        return BeeSignal.erfolg.text;
      default:
        return BeeTokens.textGedaempft;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'bestellt':
        return Icons.local_shipping;
      case 'gekauft':
        return Icons.check_circle;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAlternatives = materialAlternatives.containsKey(item.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: const EdgeInsets.all(BeeTokens.md),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MaterialDetailPage(item: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status button
                PopupMenuButton<String>(
                  onSelected: (newStatus) async {
                    await ref
                        .read(materialListProvider.notifier)
                        .updateStatus(item.id, newStatus);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'geplant', child: Text('Geplant')),
                    const PopupMenuItem(value: 'bestellt', child: Text('Bestellt')),
                    const PopupMenuItem(value: 'gekauft', child: Text('Gekauft')),
                  ],
                  child: Icon(
                    _statusIcon(item.status),
                    color: _statusColor(item.status),
                    size: 28,
                  ),
                ),
                const SizedBox(width: BeeTokens.md),
                // Vorschaubild (nur wenn Foto vorhanden)
                if (item.photoUrls.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.photoUrls.first,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        color: BeeTokens.rand,
                        child: const Icon(Icons.image_not_supported,
                            size: 18, color: BeeTokens.textGedaempft),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: BeeTokens.textPrimaer,
                          decoration: item.status == 'gekauft'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.description != null)
                        Text(
                          item.description!,
                          style: const TextStyle(
                              fontSize: 12, color: BeeTokens.textGedaempft),
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
                        color: BeeTokens.textSekundaer,
                      ),
                    ),
                    if (item.priceCHF != null)
                      Text(
                        'CHF ${NumberFormat('#,##0.00', 'de_CH').format(item.totalPrice)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: BeeTokens.textSekundaer,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // Bottom row: supplier link + badges
            const SizedBox(height: BeeTokens.sm),
            Row(
              children: [
                if (item.supplier != null)
                  item.supplierUrl != null
                      ? GestureDetector(
                          onTap: () {
                            launchUrl(Uri.parse(item.supplierUrl!),
                                mode: LaunchMode.externalApplication);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store, size: 13, color: BeeSignal.info.text),
                              const SizedBox(width: 3),
                              Text(
                                item.supplier!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BeeSignal.info.text,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.open_in_new, size: 10, color: BeeSignal.info.text),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.store, size: 13, color: BeeTokens.textGedaempft),
                            const SizedBox(width: 3),
                            Text(
                              item.supplier!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: BeeTokens.honig,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BeeTokens.honigTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Phase ${item.phase}',
                    style: const TextStyle(fontSize: 10, color: BeeTokens.textSekundaer),
                  ),
                ),
                if (hasAlternatives) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BeeTokens.honigTint,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: BeeTokens.honig.withAlpha(100)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare_arrows, size: 10, color: BeeTokens.textSekundaer),
                        SizedBox(width: 3),
                        Text(
                          'Alternativen',
                          style: TextStyle(fontSize: 10, color: BeeTokens.textSekundaer),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            ?extraInfo,
          ],
        ),
      ),
    );
  }
}
