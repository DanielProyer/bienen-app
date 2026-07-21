import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
final _qty = NumberFormat('#,##0.##', 'de_CH');

MaterialPurchase? _lastPurchase(
    Map<String, List<MaterialPurchase>> m, String id) {
  final list = m[id];
  return (list != null && list.isNotEmpty) ? list.first : null;
}

// ---------------------------------------------------------------------------
// Verbrauchsmaterial: Nachkauf-Banner + „Im Bestand" + „Auf der Einkaufsliste".
// ---------------------------------------------------------------------------
class VerbrauchAnsicht extends ConsumerWidget {
  const VerbrauchAnsicht({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verbrauch = ref.watch(verbrauchItemsProvider);
    final nachkaufen = ref.watch(nachkaufenItemsProvider);
    final purchasesByMaterial = ref.watch(purchasesByMaterialProvider);

    final imBestand = verbrauch.where((i) => i.status == 'gekauft').toList();
    final einkaufsliste = verbrauch
        .where((i) => i.status == 'geplant' || i.status == 'bestellt')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (nachkaufen.isNotEmpty) ...[
          _NachkaufBanner(items: nachkaufen),
          const SizedBox(height: 20),
        ],

        // Im Bestand
        const _SectionHeader('Im Bestand'),
        const SizedBox(height: 8),
        if (imBestand.isEmpty)
          const _EmptyHint('Noch nichts im Bestand.')
        else
          ...imBestand.map((item) => MaterialListTile(
                item: item,
                extraInfo: _BestandExtra(
                  item: item,
                  lastPurchase: _lastPurchase(purchasesByMaterial, item.id),
                ),
              )),

        const SizedBox(height: 24),

        // Auf der Einkaufsliste
        const _SectionHeader('Auf der Einkaufsliste'),
        const SizedBox(height: 8),
        if (einkaufsliste.isEmpty)
          const _EmptyHint('Die Einkaufsliste ist leer – alles vorhanden ✓')
        else
          ...einkaufsliste.map((item) => MaterialListTile(item: item)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kompaktes Nachkauf-Banner: je Artikel eine Zeile mit „Auf Einkaufsliste".
// ---------------------------------------------------------------------------
class _NachkaufBanner extends ConsumerWidget {
  final List<MaterialItem> items;
  const _NachkaufBanner({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.amber50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.honey, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
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
                    '${items.length} Artikel unter Mindestbestand',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.brown800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final item in items) _row(ref, item),
          ],
        ),
      ),
    );
  }

  Widget _row(WidgetRef ref, MaterialItem item) {
    final unit = item.unit != null ? ' ${item.unit}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown800,
                  ),
                ),
                Text(
                  'Bestand ${_qty.format(item.stockQty)} / min ${_qty.format(item.minQty)}$unit',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.honeyDark,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: const Text('Auf Einkaufsliste'),
            onPressed: () => ref
                .read(materialListProvider.notifier)
                .updateStatus(item.id, 'geplant'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// extraInfo für Bestand-Artikel: Balken + Bestand/Min + Status-Badge + Kauf.
// ---------------------------------------------------------------------------
class _BestandExtra extends StatelessWidget {
  final MaterialItem item;
  final MaterialPurchase? lastPurchase;
  const _BestandExtra({required this.item, this.lastPurchase});

  @override
  Widget build(BuildContext context) {
    final status = bestandStatus(item);
    final hasBar = item.minQty > 0;
    final barColor = status == BestandStatus.nachbestellen
        ? AppColors.amber600
        : AppColors.green600;
    final unit = item.unit != null ? ' ${item.unit}' : '';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBar) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.stockQty / item.minQty).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.brown50,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bestand ${_qty.format(item.stockQty)} / min ${_qty.format(item.minQty)}$unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown600,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          if (lastPurchase != null) ...[
            const SizedBox(height: 4),
            Text(
              _lastPurchaseLabel(lastPurchase!),
              style: const TextStyle(fontSize: 11, color: AppColors.brown300),
            ),
          ],
        ],
      ),
    );
  }

  String _lastPurchaseLabel(MaterialPurchase p) {
    final parts = <String>[];
    if (p.gekauftAm != null) {
      parts.add(DateFormat('dd.MM.yyyy').format(p.gekauftAm!));
    }
    if (p.shop != null && p.shop!.isNotEmpty) parts.add(p.shop!);
    if (p.gesamtpreis != null) parts.add('CHF ${_chf.format(p.gesamtpreis)}');
    return parts.isEmpty
        ? 'Letzter Kauf erfasst'
        : 'Letzter Kauf: ${parts.join(' · ')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final BestandStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (status) {
      case BestandStatus.genug:
        label = 'genug';
        color = AppColors.green600;
      case BestandStatus.nachbestellen:
        label = 'nachbestellen';
        color = AppColors.amber800;
      case BestandStatus.nichtRelevant:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gemeinsame kleine Bausteine.
// ---------------------------------------------------------------------------
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
