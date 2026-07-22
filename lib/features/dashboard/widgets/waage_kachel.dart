import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';

/// Platzhalter bis Modul 4.9 — bewusst OHNE Demo-Daten. Andockpunkt für die HiveWatch-Waage.
class WaageKachel extends StatelessWidget {
  const WaageKachel({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AppListTile(
        onTap: () => context.go('/monitoring'),
        leading: const Icon(Icons.monitor_weight_outlined, size: 28, color: BeeTokens.textGedaempft),
        titel: 'Waage & Sensorik',
        untertitel: 'HiveWatch-Stockwaage folgt — danach hier: Gewicht 24 h, Brutraumtemperatur, Alarme.',
      ),
    );
  }
}
