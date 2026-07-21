import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');

// ---------------------------------------------------------------------------
// Kosten-Dashboard (Ausgaben-Tab). WIDGET-Name bewusst „…Ansicht", um die
// Namenskollision mit der Domain-Klasse `KostenDashboard` zu vermeiden.
// ---------------------------------------------------------------------------
class KostenDashboardAnsicht extends ConsumerWidget {
  const KostenDashboardAnsicht({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(kostenDashboardProvider);

    if (d.leer) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch keine Ausgaben erfasst.',
            style: TextStyle(color: AppColors.brown600),
          ),
        ),
      );
    }

    final kategorien = d.proKategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final zahlungsarten = d.proZahlungsart.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final jahre = d.proJahr.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Kennzahl-Karten (2×2)
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Bisher ausgegeben',
                value: d.bisher,
                color: AppColors.green600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Investitionen',
                value: d.investitionIst,
                color: AppColors.honeyDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Laufende Kosten',
                value: d.laufendIst,
                color: AppColors.brown600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Noch geplant',
                value: d.geplant,
                color: AppColors.amber600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Budget Soll/Ist
        _BudgetCard(d: d),

        // 3. Nach Kategorie
        if (kategorien.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Header('Nach Kategorie'),
          const SizedBox(height: 10),
          _BarList(
            entries: [for (final e in kategorien) MapEntry(e.key, e.value)],
            maxValue: kategorien.first.value,
            color: AppColors.honey,
          ),
        ],

        // 4. Pro Jahr
        if (jahre.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Header('Pro Jahr'),
          const SizedBox(height: 10),
          _BarList(
            entries: [
              for (final e in jahre) MapEntry(e.key.toString(), e.value)
            ],
            maxValue:
                jahre.map((e) => e.value).reduce((a, b) => a > b ? a : b),
            color: AppColors.amber600,
          ),
        ],

        // 5. Nach Zahlungsart
        if (zahlungsarten.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Header('Nach Zahlungsart'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final e in zahlungsarten)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.brown800),
                            ),
                          ),
                          Text(
                            'CHF ${_chf.format(e.value)}',
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

        // 6. Kosten je Volk
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.hive_outlined,
                size: 16, color: AppColors.brown600),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Laufende Kosten je Volk',
                style: TextStyle(fontSize: 13, color: AppColors.brown600),
              ),
            ),
            Text(
              'CHF ${_chf.format(d.kostenJeVolk)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brown800,
              ),
            ),
          ],
        ),

        // 7. Archiv/Einmalbau (separat, gedämpft)
        if (d.archivIst > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Archiviert/Einmalbau (nicht in laufenden Kosten)',
                  style: TextStyle(fontSize: 12, color: AppColors.brown300),
                ),
              ),
              Text(
                'CHF ${_chf.format(d.archivIst)}',
                style: const TextStyle(fontSize: 12, color: AppColors.brown300),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Kennzahl-Karte (Optik aus material_page.dart recycelt).
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, height: 1.15, color: AppColors.brown600),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'CHF ${_chf.format(value)}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final KostenDashboard d;
  const _BudgetCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final anteil = d.ausschoepfung;
    final ueber = anteil > 1;
    final barColor = ueber ? Colors.red.shade600 : AppColors.honey;
    final prozent = (anteil * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Budget (Soll/Ist)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brown800,
                    ),
                  ),
                ),
                Text(
                  '$prozent%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ueber ? Colors.red.shade700 : AppColors.honeyDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: anteil.clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: AppColors.amber50,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CHF ${_chf.format(d.bisher)} von ${_chf.format(d.sollBudget)} '
              '· offen CHF ${_chf.format(d.offen)}',
              style: const TextStyle(fontSize: 12, color: AppColors.brown600),
            ),
          ],
        ),
      ),
    );
  }
}

// Horizontale Balkenliste (Container-Breite proportional zum Maximum).
class _BarList extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double maxValue;
  final Color color;
  const _BarList({
    required this.entries,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.brown800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CHF ${_chf.format(e.value)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.honeyDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 9,
                    color: AppColors.brown50,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxValue > 0
                          ? (e.value / maxValue).clamp(0, 1).toDouble()
                          : 0,
                      child: Container(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.brown800,
        ),
      );
}
