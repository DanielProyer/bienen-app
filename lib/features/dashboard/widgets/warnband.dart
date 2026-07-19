import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Rotes Warnband je Befund: überfällige Aufgaben + aktive Meldepflicht-Ereignisse.
/// Kein Befund → rendert nichts.
class Warnband extends ConsumerWidget {
  const Warnband({super.key});

  Widget _band(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            // WICHTIG: kein borderRadius hier — nicht-uniformer Border (nur left)
            // + borderRadius wirft einen Flutter-Assert; das Clipping macht das Material.
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.red.shade700, width: 4)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade900)),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.red.shade700),
            ]),
          ),
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
