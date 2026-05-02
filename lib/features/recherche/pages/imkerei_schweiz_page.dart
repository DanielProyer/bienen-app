import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class ImkereiSchweizPage extends StatelessWidget {
  const ImkereiSchweizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imkerei Schweiz')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/imkerei-schweiz/detail'),
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
              title: 'Kennzahlen Schweiz',
              subtitle: 'Stand 2022',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(context, '16\'500', 'Imker:innen'),
                _buildStatCard(context, '182\'000', 'Bienenvölker'),
                _buildStatCard(context, '11.1', 'Völker/Imker'),
                _buildStatCard(context, '4.4', 'Völker/km²'),
              ],
            ),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Verbände',
              subtitle: 'Organisiert nach Sprachregion unter apisuisse',
            ),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'BienenSchweiz (VDRB)',
              content: 'Deutsch- und Rätoromanische Schweiz\nca. 14\'000 Mitglieder',
              icon: Icons.groups,
            ),
            const InfoCard(
              title: 'Bündner Imkerverband',
              content: 'apis-grischun.ch\n15 Sektionen, 2 Lehrbienenstände\nGrundausbildungskurse',
              icon: Icons.location_on,
              highlight: true,
            ),
            const InfoCard(
              title: 'Plantahof (Landquart)',
              content: 'Eidg. Fachausweis für Imker/innen\nKoordiniertes Varroa-Behandlungsprojekt seit 2013',
              icon: Icons.school,
            ),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Ausbildung',
              subtitle: 'Empfohlen vor dem Start',
            ),
            const SizedBox(height: 16),
            _buildEducationCard(
              context,
              'Grundkurs (Einsteiger)',
              [
                '18 Halbtage über 2 Jahre',
                'Theorie + Praxis am Bienenstand',
                'Lehrmittel: Schweizerisches Bienenbuch',
                'Abschluss: Kurszertifikat und Diplom',
              ],
            ),
            _buildEducationCard(
              context,
              'Eidg. Fachausweis',
              [
                '27 Ausbildungstage in 5 Modulen',
                'Voraussetzung: Grundkurs + 3 Jahre Praxis',
                'Durchführung: Plantahof (GR)',
              ],
            ),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Gesetzliche Grundlagen',
              subtitle: 'Kanton Graubünden',
            ),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Registrierungspflicht',
              content: 'Alle Bienenstände müssen beim ALT GR registriert werden.\nMeldepflicht bei Standortwechsel.',
              icon: Icons.gavel,
            ),
            const InfoCard(
              title: 'Tierseuchengesetz',
              content: 'Meldepflichtige Seuchen: Faulbrut, Sauerbrut\nBieneninspektor kontrolliert regelmässig',
              icon: Icons.health_and_safety,
            ),
            const SizedBox(height: 32),
            const SectionHeader(
              title: 'Imkerei auf 1570 m',
              subtitle: 'Besonderheiten Höhenlage',
            ),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Herausforderungen',
              content: '• Kurze Saison (ca. 3-4 Monate)\n• Lange Winter (Nov-März Winterruhe)\n• 40-45 Tage Verschiebung vs. Tallagen\n• Heftige Wetterwechsel\n• Grosse Wintervorräte nötig (15-20 kg Sirup/Volk)',
              icon: Icons.terrain,
            ),
            const InfoCard(
              title: 'Vorteile',
              content: '• Premium-Honig (Alpenblüten, Alpenrosen)\n• Weniger Pestizidbelastung\n• Geringerer Krankheitsdruck\n• Hohe Preise erzielbar (CHF 18-25/500g)',
              icon: Icons.star,
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.honeyDark,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.brown600)),
        ],
      ),
    );
  }

  Widget _buildEducationCard(
      BuildContext context, String title, List<String> points) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(p)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
