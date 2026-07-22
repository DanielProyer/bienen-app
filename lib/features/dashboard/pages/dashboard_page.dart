import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/dashboard/widgets/heute_karte.dart';
import 'package:bienen_app/features/dashboard/widgets/voelker_karte.dart';
import 'package:bienen_app/features/dashboard/widgets/waage_kachel.dart';
import 'package:bienen_app/features/dashboard/widgets/warnband.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _wochentage = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final datum = '${_wochentage[jetzt.weekday - 1]}, ${jetzt.day}.${jetzt.month}.${jetzt.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cockpit'),
        actions: [
          IconButton(
            tooltip: 'Konto & Team',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/konto'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: BeeTokens.xs, bottom: BeeTokens.md),
              child: Text(datum, style: const TextStyle(fontSize: 13, color: BeeTokens.textGedaempft)),
            ),
            const Warnband(),
            const HeuteKarte(),
            const SizedBox(height: BeeTokens.md),
            const VoelkerKarte(),
            const SizedBox(height: BeeTokens.md),
            const WaageKachel(),
            const SizedBox(height: BeeTokens.xl),
          ],
        ),
      ),
    );
  }
}
