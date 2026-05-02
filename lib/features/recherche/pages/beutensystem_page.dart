import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class BeutensystemPage extends StatelessWidget {
  const BeutensystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beutensystem')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Dadant Blatt 10er',
              subtitle: 'Gewähltes Beutensystem in Holz',
            ),
            const SizedBox(height: 24),
            _buildDecisionBanner(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Technische Spezifikationen'),
            const SizedBox(height: 16),
            _buildSpecsTable(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Warum Dadant Blatt?'),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Grosser Brutraum',
              content: 'Eine einzige Zarge für den Brutraum - kein Umhängen nötig.\nKönigin hat Platz für volle Entfaltung.',
              icon: Icons.fullscreen,
            ),
            const InfoCard(
              title: 'Trennung Brut/Honig',
              content: 'Absperrgitter trennt Brutraum und Honigraum sauber.\nHalbzargen im Honigraum = leichter zu handhaben.',
              icon: Icons.view_agenda,
            ),
            const InfoCard(
              title: 'International verbreitet',
              content: 'Weltweit am meisten genutztes System bei Profis.\nViel Literatur, Erfahrungsaustausch, Zubehör verfügbar.',
              icon: Icons.public,
            ),
            const InfoCard(
              title: 'Bio-kompatibel (Holz)',
              content: 'Weymouthskiefer, 25-30 mm Wandstärke.\nNatürliches Material, kein Styropor/Kunststoff.\nErfüllt Bio-Suisse Anforderungen.',
              icon: Icons.eco,
              highlight: true,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Besonderheiten für Höhenlage'),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Wärmeschied',
              content: 'Styrodur-Schied zur Brutraum-Einengung.\nWichtig für die langen Winter auf 1570 m.\nVolksstärke an Raumgrösse angepasst.',
              icon: Icons.thermostat,
            ),
            const InfoCard(
              title: 'Deckelisolation',
              content: 'Styrodur 30-50 mm unter dem Blechdeckel.\nVerhindert Kondenswasser im Winter.\nSchützt vor extremen Temperaturschwankungen.',
              icon: Icons.roofing,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Aufbau einer Dadant-Blatt-Beute'),
            const SizedBox(height: 16),
            _buildBeuteSchema(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green400),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.green600, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entscheidung: Dadant Blatt 10er in Holz',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.green800,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Weymouthskiefer · Bio-kompatibel · Qualität vor Preis',
                  style: TextStyle(color: AppColors.green800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsTable(BuildContext context) {
    final specs = [
      ['Innenmaß Brutraum', '465 × 285 mm (Wabe)'],
      ['Wabenanzahl Brut', '10 Dadant-Blatt-Waben'],
      ['Innenmaß Honigraum', '465 × 137 mm (Halbwabe)'],
      ['Wabenanzahl Honig', '11 pro Halbzarge'],
      ['Wandstärke', '25-30 mm (Holz)'],
      ['Beutenmaterial', 'Weymouthskiefer'],
      ['Boden', 'Hochboden mit Varroagitter'],
      ['Deckel', 'Blechdeckel + Styrodur-Isolation'],
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1.5),
          },
          children: specs
              .map((row) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          row[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.brown600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(row[1]),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBeuteSchema(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSchemaRow('Blechdeckel', AppColors.brown300),
            _buildSchemaRow('Styrodur-Isolation (30-50 mm)', AppColors.amber100),
            _buildSchemaRow('Innendeckel', AppColors.brown100),
            _buildSchemaRow('Honigraum 2 (Halbzarge, 11 Rähmchen)', AppColors.amber200),
            _buildSchemaRow('Honigraum 1 (Halbzarge, 11 Rähmchen)', AppColors.amber400),
            _buildSchemaRow('Absperrgitter', AppColors.brown300),
            _buildSchemaRow('Brutraum (10 DB-Waben + Schied)', AppColors.honeyLight),
            _buildSchemaRow('Hochboden mit Varroagitter', AppColors.brown600),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemaRow(String label, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(100),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
