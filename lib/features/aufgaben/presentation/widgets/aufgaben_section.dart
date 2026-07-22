import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

/// Volk-Detailseite: bis zu 5 offene Aufgaben dieses Volks.
class AufgabenSection extends ConsumerWidget {
  final String volkId;
  const AufgabenSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offene = ref.watch(aufgabenFuerVolkProvider(volkId));
    if (offene.isEmpty) return const SizedBox.shrink();
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            titel: 'Offene Aufgaben',
            action: AppButton(
              label: 'alle →',
              kind: AppButtonKind.text,
              onPressed: () => context.go('/aufgaben'),
            ),
          ),
          for (final a in offene.take(5))
            AppListTile(
              leading: Icon(Icons.radio_button_unchecked,
                  size: 20,
                  color: a.faelligAm.isBefore(h) ? BeeSignal.gefahr.text : BeeTokens.textGedaempft),
              titel: a.titel,
              trailing: StatusPill(
                label: DateFormat('dd.MM.').format(a.faelligAm),
                signal: a.faelligAm.isBefore(h) ? BeeSignal.gefahr : BeeSignal.neutral,
              ),
            ),
        ],
      ),
    );
  }
}
