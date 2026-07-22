import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

class RaumkonzeptPage extends StatelessWidget {
  const RaumkonzeptPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raumkonzept')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/raumkonzept/detail'),
        icon: const Icon(Icons.article),
        label: const Text('Vollständige Recherche'),
        backgroundColor: BeeTokens.honig,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Raumkonzept Maiensäss',
              subtitle: 'Tannen 85a, Arosa · 4-5 Völker (ab 2036: max. 8)',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildSavingsBanner(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Drei Bereiche'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Bienenstand (Bestehender Unterstand)',
              content:
                  '4-5 Dadant-Blatt-Beuten (Platz für 8 ab 2036)\nOptimale Ausrichtung vorhanden\nFluglöcher Richtung Süd/Südost\nBienentränke 5-20 m seitlich',
              icon: Icons.hive,
              highlight: true,
            ),
            const InfoCard(
              title: 'Schleuderraum (Stall OG)',
              content:
                  'Aktuell leer - 12-15 m² verfügbar\nHonigverarbeitung: Schleuder, Rührwerk, Abfüllung\nGeplant: Logar 20/8 Radial (20 Halbrahmen, Motor)\nCFM 100 kg Rührwerk (doppelwandig)',
              icon: Icons.precision_manufacturing,
            ),
            const InfoCard(
              title: 'Lager + Honiglager (Stall EG)',
              content:
                  'Bereits in Nutzung als Werkstatt\nZargen, Waben, Werkzeug, Varroa-Mittel\nHoniglager: kühl, dunkel, 2-3 m²',
              icon: Icons.warehouse,
            ),
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(title: 'Phasenplan & Investitionen'),
            const SizedBox(height: BeeTokens.lg),
            _buildPhaseCard(context, 1, 'Herbst 2026', 'CHF 2\'150', [
              '1 Volk aufstellen',
              'Beutenständer im Unterstand',
              'Grundausstattung Werkzeug',
              'Schutzkleidung, Varroa-Mittel',
            ]),
            _buildPhaseCard(context, 2, 'Frühling 2027', 'CHF 4\'650', [
              '2 Völker',
              'Honigschleuder Logar 20/8',
              'Erste Honigernte möglich',
              'Erweiterungsmaterial',
            ]),
            _buildPhaseCard(context, 3, '2027/2028', 'CHF 17-26k', [
              'Schleuderraum OG ausbauen',
              '3-5 Völker',
              'Professionelle Honigverarbeitung',
              'Rührwerk CFM 100 kg',
              'Wasseranschluss + Abfluss',
            ]),
            _buildPhaseCard(context, 4, '2029-2035', 'Betrieb', [
              'Stabilisierung 4-5 Völker',
              'Optimierung Bienenstand',
              'Routine-Betrieb',
            ]),
            _buildPhaseCard(context, 5, 'Ab 2036', 'CHF 3\'400', [
              'Pensionierung Lorena',
              'Erweiterung auf max. 8 Völker',
              'Vollausbau Bienenstand',
            ]),
            const SizedBox(height: BeeTokens.xl),
            _buildTotalCard(context),
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(title: 'Profi-Equipment (Highlights)'),
            const SizedBox(height: BeeTokens.lg),
            _buildEquipmentCard(
              context,
              'Logar 20/8 Radial',
              'Honigschleuder · CHF 1\'900',
              '20 Halbrahmen gleichzeitig, Motorantrieb',
            ),
            _buildEquipmentCard(
              context,
              'CFM 100 kg Rührwerk',
              'Doppelwandig · CHF 3\'500',
              'Cremig rühren, temperierbar, Edelstahl',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeSignal.erfolg.flaeche,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeSignal.erfolg.text, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.savings, color: BeeSignal.erfolg.text, size: 36),
          const SizedBox(width: BeeTokens.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ersparnis durch vorhandene Infrastruktur',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BeeSignal.erfolg.text,
                  ),
                ),
                const SizedBox(height: BeeTokens.xs),
                Text(
                  'CHF 20\'000 - 28\'000 gespart!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: BeeSignal.erfolg.text,
                  ),
                ),
                const SizedBox(height: BeeTokens.xs),
                Text(
                  'Kein Neubau Unterstand + Stallgebäude vorhanden',
                  style: TextStyle(color: BeeSignal.erfolg.text, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(BuildContext context, int phase, String timing,
      String budget, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BeeTokens.honig,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$phase',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: BeeTokens.md),
                Expanded(
                  child: Text(
                    'Phase $phase: $timing',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: BeeTokens.textPrimaer,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BeeTokens.md, vertical: BeeTokens.xs),
                  decoration: BoxDecoration(
                    color: BeeTokens.honigTint,
                    borderRadius: BorderRadius.circular(BeeTokens.sm),
                  ),
                  child: Text(
                    budget,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: BeeTokens.textSekundaer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeeTokens.md),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: BeeTokens.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: BeeTokens.textGedaempft)),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                color: BeeTokens.textGedaempft)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.honig, width: 0.5),
      ),
      child: Column(
        children: [
          const Text(
            'Gesamtinvestition',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: BeeTokens.textPrimaer),
          ),
          const SizedBox(height: BeeTokens.sm),
          const Text(
            'CHF 27\'000 - 36\'000',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: BeeTokens.textSekundaer,
            ),
          ),
          const SizedBox(height: BeeTokens.xs),
          const Text(
            'über 4-5 Jahre verteilt',
            style: TextStyle(color: BeeTokens.textGedaempft),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(
      BuildContext context, String name, String subtitle, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.star, color: BeeTokens.honig),
          title: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: BeeTokens.textPrimaer)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle,
                  style: const TextStyle(
                      color: BeeTokens.textSekundaer,
                      fontWeight: FontWeight.w500)),
              Text(desc,
                  style: const TextStyle(
                      color: BeeTokens.textGedaempft, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
