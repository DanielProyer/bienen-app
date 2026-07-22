import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

class BeutensystemPage extends StatelessWidget {
  const BeutensystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beutensystem')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/beutensystem/detail'),
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
              title: 'Dadant Blatt 10er',
              subtitle: 'Gewähltes Beutensystem in Holz',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildDecisionBanner(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Technische Spezifikationen'),
            const SizedBox(height: BeeTokens.lg),
            _buildSpecsTable(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Warum Dadant Blatt?'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Grosser Brutraum',
              content:
                  'Eine einzige Zarge für den Brutraum - kein Umhängen nötig.\nKönigin hat Platz für volle Entfaltung.',
              icon: Icons.fullscreen,
            ),
            const InfoCard(
              title: 'Trennung Brut/Honig',
              content:
                  'Absperrgitter trennt Brutraum und Honigraum sauber.\nHalbzargen im Honigraum = leichter zu handhaben.',
              icon: Icons.view_agenda,
            ),
            const InfoCard(
              title: 'International verbreitet',
              content:
                  'Weltweit am meisten genutztes System bei Profis.\nViel Literatur, Erfahrungsaustausch, Zubehör verfügbar.',
              icon: Icons.public,
            ),
            const InfoCard(
              title: 'Bio-kompatibel (Holz)',
              content:
                  'Weymouthskiefer, 25-30 mm Wandstärke.\nNatürliches Material, kein Styropor/Kunststoff.\nErfüllt Bio-Suisse Anforderungen.',
              icon: Icons.eco,
              highlight: true,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Besonderheiten für Höhenlage'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Wärmeschied',
              content:
                  'Styrodur-Schied zur Brutraum-Einengung.\nWichtig für die langen Winter auf 1570 m.\nVolksstärke an Raumgrösse angepasst.',
              icon: Icons.thermostat,
            ),
            const InfoCard(
              title: 'Deckelisolation',
              content:
                  'Styrodur 30-50 mm unter dem Blechdeckel.\nVerhindert Kondenswasser im Winter.\nSchützt vor extremen Temperaturschwankungen.',
              icon: Icons.roofing,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Aufbau einer Dadant-Blatt-Beute'),
            const SizedBox(height: BeeTokens.lg),
            _buildBeuteSchema(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionBanner(BuildContext context) {
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
          Icon(Icons.check_circle, color: BeeSignal.erfolg.text, size: 32),
          const SizedBox(width: BeeTokens.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entscheidung: Dadant Blatt 10er in Holz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BeeSignal.erfolg.text,
                  ),
                ),
                const SizedBox(height: BeeTokens.xs),
                Text(
                  'Weymouthskiefer · Bio-kompatibel · Qualität vor Preis',
                  style: TextStyle(color: BeeSignal.erfolg.text),
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

    return AppCard(
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
                          color: BeeTokens.textGedaempft,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(row[1],
                          style: const TextStyle(color: BeeTokens.textPrimaer)),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBeuteSchema(BuildContext context) {
    const layers = [
      'Blechdeckel',
      'Styrodur-Isolation (30-50 mm)',
      'Innendeckel',
      'Honigraum 2 (Halbzarge, 11 Rähmchen)',
      'Honigraum 1 (Halbzarge, 11 Rähmchen)',
      'Absperrgitter',
      'Brutraum (10 DB-Waben + Schied)',
      'Hochboden mit Varroagitter',
    ];
    return AppCard(
      padding: const EdgeInsets.all(BeeTokens.lg),
      child: Column(
        children: layers.map(_buildSchemaRow).toList(),
      ),
    );
  }

  Widget _buildSchemaRow(String label) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        border: Border.all(color: BeeTokens.rand),
        borderRadius: BorderRadius.circular(BeeTokens.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: BeeTokens.textPrimaer),
        textAlign: TextAlign.center,
      ),
    );
  }
}
