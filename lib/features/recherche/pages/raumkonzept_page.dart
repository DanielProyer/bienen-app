import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

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
        backgroundColor: AppColors.honey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Raumkonzept Maiensäss',
              subtitle: 'Tannen 85a, Arosa · 4-5 Völker (ab 2036: max. 8)',
            ),
            const SizedBox(height: 24),
            _buildSavingsBanner(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Drei Bereiche'),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Bienenstand (Bestehender Unterstand)',
              content: '4-5 Dadant-Blatt-Beuten (Platz für 8 ab 2036)\nOptimale Ausrichtung vorhanden\nFluglöcher Richtung Süd/Südost\nBienentränke 5-20 m seitlich',
              icon: Icons.hive,
              highlight: true,
            ),
            const InfoCard(
              title: 'Schleuderraum (Stall OG)',
              content: 'Aktuell leer - 12-15 m² verfügbar\nHonigverarbeitung: Schleuder, Rührwerk, Abfüllung\nGeplant: Logar 20/8 Radial (20 Halbrahmen, Motor)\nCFM 100 kg Rührwerk (doppelwandig)',
              icon: Icons.precision_manufacturing,
            ),
            const InfoCard(
              title: 'Lager + Honiglager (Stall EG)',
              content: 'Bereits in Nutzung als Werkstatt\nZargen, Waben, Werkzeug, Varroa-Mittel\nHoniglager: kühl, dunkel, 2-3 m²',
              icon: Icons.warehouse,
            ),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Phasenplan & Investitionen'),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            _buildTotalCard(context),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Profi-Equipment (Highlights)'),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green50, AppColors.amber50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green400),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings, color: AppColors.green600, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ersparnis durch vorhandene Infrastruktur',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.green800,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CHF 20\'000 - 28\'000 gespart!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kein Neubau Unterstand + Stallgebäude vorhanden',
                  style: TextStyle(color: AppColors.green800, fontSize: 13),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.honey,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$phase',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Phase $phase: $timing',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    budget,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.honeyDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: AppColors.brown600)),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(color: AppColors.brown600)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber400),
      ),
      child: Column(
        children: [
          const Text(
            'Gesamtinvestition',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'CHF 27\'000 - 36\'000',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.honeyDark,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'über 4-5 Jahre verteilt',
            style: TextStyle(color: AppColors.brown600),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(
      BuildContext context, String name, String subtitle, String desc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.star, color: AppColors.honey),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.honeyDark, fontWeight: FontWeight.w500)),
            Text(desc,
                style:
                    const TextStyle(color: AppColors.brown300, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
