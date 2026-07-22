import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';

/// Warnband je Befund: überfällige Aufgaben + aktive Meldepflicht-Ereignisse.
/// Kein Befund → rendert nichts.
class Warnband extends ConsumerWidget {
  const Warnband({super.key});

  Widget _band(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: Container(
        decoration: BoxDecoration(
          color: BeeSignal.gefahr.flaeche,
          borderRadius: BorderRadius.circular(BeeTokens.rKarte),
          border: Border.all(color: BeeTokens.rand, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: AppListTile(
          onTap: onTap,
          leading: Icon(icon, size: 20, color: BeeSignal.gefahr.text),
          titel: text,
          trailing: Icon(Icons.chevron_right, color: BeeSignal.gefahr.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baender = <Widget>[];
    final stats = ref.watch(offeneAufgabenStatsProvider);
    if (stats.ueberfaellig > 0) {
      baender.add(_band(context,
          icon: Icons.warning_amber,
          text: stats.ueberfaellig == 1 ? '1 Aufgabe überfällig' : '${stats.ueberfaellig} Aufgaben überfällig',
          onTap: () => context.go('/aufgaben')));
    }
    for (final volk in ref.watch(aktiveVoelkerProvider)) {
      final melde = ref.watch(aktiveMeldepflichtProvider(volk.id));
      if (melde.isNotEmpty) {
        baender.add(_band(context,
            icon: Icons.report,
            text: 'Meldepflicht aktiv: ${volk.name}',
            onTap: () => context.go('/voelker/${volk.id}')));
      }
    }
    if (baender.isEmpty) return const SizedBox.shrink();
    return Column(children: baender);
  }
}
