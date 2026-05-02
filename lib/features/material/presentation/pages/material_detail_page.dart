import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_alternatives.dart';
import 'package:intl/intl.dart';

class MaterialDetailPage extends StatelessWidget {
  final MaterialItem item;

  const MaterialDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final alternatives = materialAlternatives[item.name];

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main product card
            _buildMainProductCard(context),
            const SizedBox(height: 24),

            // Alternatives
            if (alternatives != null && alternatives.isNotEmpty) ...[
              Text(
                'Alternativen & Vergleich',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brown800,
                ),
              ),
              const SizedBox(height: 12),
              ...alternatives.map((alt) => _buildAlternativeCard(context, alt)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainProductCard(BuildContext context) {
    final productInfo = materialProductInfo[item.name];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor(item.status)),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(item.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brown50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Phase ${item.phase}',
                    style: TextStyle(fontSize: 11, color: AppColors.brown600),
                  ),
                ),
                const Spacer(),
                Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.honeyDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              item.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800,
              ),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                style: TextStyle(fontSize: 14, color: AppColors.brown600),
              ),
            ],

            // Extended product info
            if (productInfo != null) ...[
              const SizedBox(height: 12),
              Text(
                productInfo,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Price & quantity
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Menge', style: TextStyle(fontSize: 11, color: AppColors.brown300)),
                    Text(
                      '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                if (item.priceCHF != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stückpreis', style: TextStyle(fontSize: 11, color: AppColors.brown300)),
                      Text(
                        'CHF ${NumberFormat('#,##0.00', 'de_CH').format(item.priceCHF)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 11, color: AppColors.brown300)),
                    Text(
                      'CHF ${NumberFormat('#,##0.00', 'de_CH').format(item.totalPrice)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.honeyDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Supplier & links
            if (item.supplier != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Lieferant', style: TextStyle(fontSize: 11, color: AppColors.brown300)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: AppColors.honeyDark),
                  const SizedBox(width: 6),
                  Text(
                    item.supplier!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brown800,
                    ),
                  ),
                ],
              ),
              if (item.supplierUrl != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Im Shop öffnen'),
                    onPressed: () => _openUrl(item.supplierUrl!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.honeyDark,
                      side: BorderSide(color: AppColors.honey),
                    ),
                  ),
                ),
              ],
            ],

            // Notes
            if (item.notes != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Notizen', style: TextStyle(fontSize: 11, color: AppColors.brown300)),
              const SizedBox(height: 4),
              Text(item.notes!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeCard(BuildContext context, ProductAlternative alt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alt.isRecommended ? AppColors.amber50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alt.isRecommended
            ? BorderSide(color: AppColors.honey, width: 2)
            : BorderSide(color: AppColors.brown100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    alt.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (alt.isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.honey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'EMPFEHLUNG',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),

            // Supplier & Price
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  alt.supplier,
                  style: TextStyle(fontSize: 12, color: AppColors.brown600),
                ),
                const Spacer(),
                Text(
                  alt.price,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.honeyDark,
                  ),
                ),
              ],
            ),

            // Pros
            if (alt.pros.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...alt.pros.map((pro) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.add_circle, size: 14, color: AppColors.green600),
                        const SizedBox(width: 6),
                        Expanded(child: Text(pro, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
            ],

            // Cons
            if (alt.cons.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...alt.cons.map((con) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.remove_circle, size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(child: Text(con, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
            ],

            // Link
            if (alt.url != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openUrl(alt.url!),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alt.url!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
