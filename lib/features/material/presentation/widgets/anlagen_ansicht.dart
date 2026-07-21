import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');

MaterialPurchase? _lastPurchase(
    Map<String, List<MaterialPurchase>> m, String id) {
  final list = m[id];
  return (list != null && list.isNotEmpty) ? list.first : null;
}

// ---------------------------------------------------------------------------
// Anlagegüter (langlebig): „Vorhanden" + „Geplant". Kein Bestand/Nachkauf.
// ---------------------------------------------------------------------------
class AnlagenAnsicht extends ConsumerWidget {
  const AnlagenAnsicht({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anlagen = ref.watch(anlageItemsProvider);
    final purchasesByMaterial = ref.watch(purchasesByMaterialProvider);

    final vorhanden = anlagen.where((i) => i.status == 'gekauft').toList();
    final geplant = anlagen
        .where((i) => i.status == 'geplant' || i.status == 'bestellt')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Vorhanden'),
        const SizedBox(height: 8),
        if (vorhanden.isEmpty)
          const _EmptyHint('Noch keine Anlagegüter vorhanden.')
        else
          ...vorhanden.map((item) => MaterialListTile(
                item: item,
                extraInfo: _AnlageExtra(
                  item: item,
                  lastPurchase: _lastPurchase(purchasesByMaterial, item.id),
                ),
              )),

        const SizedBox(height: 24),

        const _SectionHeader('Geplant'),
        const SizedBox(height: 8),
        if (geplant.isEmpty)
          const _EmptyHint('Nichts geplant.')
        else
          ...geplant.map((item) => MaterialListTile(item: item)),
      ],
    );
  }
}

class _AnlageExtra extends StatelessWidget {
  final MaterialItem item;
  final MaterialPurchase? lastPurchase;
  const _AnlageExtra({required this.item, this.lastPurchase});

  @override
  Widget build(BuildContext context) {
    final unit = item.unit != null ? ' ${item.unit}' : '';
    final parts = <String>['Anzahl ${item.quantity}$unit'];
    if (item.priceCHF != null) {
      parts.add('CHF ${_chf.format(item.priceCHF)}');
    }
    final jahr = lastPurchase?.gekauftAm?.year;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.join(' · '),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brown600,
            ),
          ),
          if (jahr != null) ...[
            const SizedBox(height: 3),
            Text(
              'Angeschafft $jahr',
              style: const TextStyle(fontSize: 11, color: AppColors.brown300),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.brown800,
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.brown300, fontSize: 13),
        ),
      );
}
