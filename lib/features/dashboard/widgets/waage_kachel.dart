import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

/// Platzhalter bis Modul 4.9 — bewusst OHNE Demo-Daten. Andockpunkt für die HiveWatch-Waage.
class WaageKachel extends StatelessWidget {
  const WaageKachel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/monitoring'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.monitor_weight_outlined, size: 28, color: AppColors.brown300),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Waage & Sensorik', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('HiveWatch-Stockwaage folgt — danach hier: Gewicht 24 h, Brutraumtemperatur, Alarme.',
                    style: TextStyle(fontSize: 12, color: AppColors.brown300)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.brown300),
          ]),
        ),
      ),
    );
  }
}
