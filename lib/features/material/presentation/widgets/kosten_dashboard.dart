import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/stat_tile.dart';

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
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        titel: 'Noch keine Ausgaben erfasst.',
      );
    }

    final kategorien = d.proKategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final zahlungsarten = d.proZahlungsart.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final jahre = d.proJahr.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(BeeTokens.lg),
      children: [
        // 1. Kennzahl-Kacheln (2×2)
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Bisher ausgegeben',
                wert: 'CHF ${_chf.format(d.bisher)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Investitionen',
                wert: 'CHF ${_chf.format(d.investitionIst)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Laufende Kosten',
                wert: 'CHF ${_chf.format(d.laufendIst)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Noch geplant',
                wert: 'CHF ${_chf.format(d.geplant)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: BeeTokens.xl),

        // 2. Budget Soll/Ist
        _BudgetCard(d: d),

        // 3. Nach Kategorie
        if (kategorien.isNotEmpty) ...[
          const SizedBox(height: BeeTokens.xl),
          const SectionHeader(titel: 'Nach Kategorie'),
          _BarList(
            entries: [for (final e in kategorien) MapEntry(e.key, e.value)],
            maxValue: kategorien.first.value,
          ),
        ],

        // 4. Pro Jahr
        if (jahre.isNotEmpty) ...[
          const SizedBox(height: BeeTokens.xl),
          const SectionHeader(titel: 'Pro Jahr'),
          _BarList(
            entries: [
              for (final e in jahre) MapEntry(e.key.toString(), e.value)
            ],
            maxValue:
                jahre.map((e) => e.value).reduce((a, b) => a > b ? a : b),
          ),
        ],

        // 5. Nach Zahlungsart
        if (zahlungsarten.isNotEmpty) ...[
          const SizedBox(height: BeeTokens.xl),
          const SectionHeader(titel: 'Nach Zahlungsart'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.xs),
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
                                fontSize: 14, color: BeeTokens.textPrimaer),
                          ),
                        ),
                        Text(
                          'CHF ${_chf.format(e.value)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: BeeTokens.textSekundaer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 6. Kosten je Volk
        const SizedBox(height: BeeTokens.xl),
        Row(
          children: [
            const Icon(Icons.hive_outlined,
                size: 16, color: BeeTokens.textSekundaer),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Laufende Kosten je Volk',
                style: TextStyle(fontSize: 13, color: BeeTokens.textSekundaer),
              ),
            ),
            Text(
              'CHF ${_chf.format(d.kostenJeVolk)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textPrimaer,
              ),
            ),
          ],
        ),

        // 7. Archiv/Einmalbau (separat, gedämpft)
        if (d.archivIst > 0) ...[
          const SizedBox(height: BeeTokens.md),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Archiviert/Einmalbau (nicht in laufenden Kosten)',
                  style: TextStyle(fontSize: 12, color: BeeTokens.textGedaempft),
                ),
              ),
              Text(
                'CHF ${_chf.format(d.archivIst)}',
                style: const TextStyle(fontSize: 12, color: BeeTokens.textGedaempft),
              ),
            ],
          ),
        ],
      ],
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
    final barColor = ueber ? BeeSignal.gefahr.text : BeeTokens.honig;
    final prozent = (anteil * 100).round();

    return AppCard(
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
                    color: BeeTokens.textPrimaer,
                  ),
                ),
              ),
              Text(
                '$prozent%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ueber ? BeeSignal.gefahr.text : BeeTokens.textSekundaer,
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
              backgroundColor: BeeTokens.honigTint,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: BeeTokens.sm),
          Text(
            'CHF ${_chf.format(d.bisher)} von ${_chf.format(d.sollBudget)} '
            '· offen CHF ${_chf.format(d.offen)}',
            style: const TextStyle(fontSize: 12, color: BeeTokens.textSekundaer),
          ),
        ],
      ),
    );
  }
}

// Horizontale Balkenliste (Container-Breite proportional zum Maximum).
class _BarList extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double maxValue;
  const _BarList({
    required this.entries,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: BeeTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontSize: 13, color: BeeTokens.textPrimaer),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: BeeTokens.sm),
                    Text(
                      'CHF ${_chf.format(e.value)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textSekundaer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 9,
                    color: BeeTokens.rand,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxValue > 0
                          ? (e.value / maxValue).clamp(0, 1).toDouble()
                          : 0,
                      child: Container(color: BeeTokens.honig),
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
