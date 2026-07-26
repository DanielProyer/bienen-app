import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class CurrentWeightCard extends ConsumerWidget {
  const CurrentWeightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestReadingProvider);
    final dailyChange = ref.watch(dailyWeightChangeProvider);
    final nf = NumberFormat('#,##0.0', 'de_CH');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(titel: 'Aktuelles Gewicht'),
          if (latest != null) ...[
            Text(
              '${nf.format(latest.weightKg)} kg',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: BeeTokens.textPrimaer,
                height: 1.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: BeeTokens.sm),
            if (dailyChange != null) _DeltaChip(deltaKg: dailyChange),
            const SizedBox(height: BeeTokens.sm),
            Text(latest.hiveName, style: BeeTokens.gedaempft),
            Text(
              'Letzte Messung: ${DateFormat('dd.MM. HH:mm', 'de_CH').format(latest.recordedAt.toLocal())}',
              style: BeeTokens.gedaempft,
            ),
          ] else
            const Text(
              'Keine Daten',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: BeeTokens.textGedaempft,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double deltaKg;

  const _DeltaChip({required this.deltaKg});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('+#,##0.0;-#,##0.0', 'de_CH');
    final isPositive = deltaKg >= 0;
    final signal = isPositive ? BeeSignal.erfolg : BeeSignal.gefahr;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: BeeTokens.md, vertical: BeeTokens.xs),
      decoration: BoxDecoration(
        color: signal.flaeche,
        borderRadius: BorderRadius.circular(BeeTokens.rPille),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: signal.text),
          const SizedBox(width: BeeTokens.xs),
          Text(
            '${nf.format(deltaKg)} kg / 24h',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: signal.text,
            ),
          ),
        ],
      ),
    );
  }
}
