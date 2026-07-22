import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/stat_tile.dart';

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
        backgroundColor: BeeTokens.honig,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Kennzahlen Schweiz',
              subtitle: 'Stand 2022',
            ),
            const SizedBox(height: BeeTokens.lg),
            Wrap(
              spacing: BeeTokens.md,
              runSpacing: BeeTokens.md,
              children: const [
                _StatBox(wert: '16\'500', label: 'Imker:innen'),
                _StatBox(wert: '182\'000', label: 'Bienenvölker'),
                _StatBox(wert: '11.1', label: 'Völker/Imker'),
                _StatBox(wert: '4.4', label: 'Völker/km²'),
              ],
            ),
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(
              title: 'Verbände',
              subtitle: 'Organisiert nach Sprachregion unter apisuisse',
            ),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'BienenSchweiz (VDRB)',
              content:
                  'Deutsch- und Rätoromanische Schweiz\nca. 14\'000 Mitglieder',
              icon: Icons.groups,
            ),
            const InfoCard(
              title: 'Bündner Imkerverband',
              content:
                  'apis-grischun.ch\n15 Sektionen, 2 Lehrbienenstände\nGrundausbildungskurse',
              icon: Icons.location_on,
              highlight: true,
            ),
            const InfoCard(
              title: 'Plantahof (Landquart)',
              content:
                  'Eidg. Fachausweis für Imker/innen\nKoordiniertes Varroa-Behandlungsprojekt seit 2013',
              icon: Icons.school,
            ),
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(
              title: 'Ausbildung',
              subtitle: 'Empfohlen vor dem Start',
            ),
            const SizedBox(height: BeeTokens.lg),
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
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(
              title: 'Gesetzliche Grundlagen',
              subtitle: 'Kanton Graubünden',
            ),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Registrierungspflicht',
              content:
                  'Alle Bienenstände müssen beim ALT GR registriert werden.\nMeldepflicht bei Standortwechsel.',
              icon: Icons.gavel,
            ),
            const InfoCard(
              title: 'Tierseuchengesetz',
              content:
                  'Meldepflichtige Seuchen: Faulbrut, Sauerbrut\nBieneninspektor kontrolliert regelmässig',
              icon: Icons.health_and_safety,
            ),
            const SizedBox(height: BeeTokens.xxl),
            const SectionHeader(
              title: 'Imkerei auf 1570 m',
              subtitle: 'Besonderheiten Höhenlage',
            ),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Herausforderungen',
              content:
                  '• Kurze Saison (ca. 3-4 Monate)\n• Lange Winter (Nov-März Winterruhe)\n• 40-45 Tage Verschiebung vs. Tallagen\n• Heftige Wetterwechsel\n• Grosse Wintervorräte nötig (15-20 kg Sirup/Volk)',
              icon: Icons.terrain,
            ),
            const InfoCard(
              title: 'Vorteile',
              content:
                  '• Premium-Honig (Alpenblüten, Alpenrosen)\n• Weniger Pestizidbelastung\n• Geringerer Krankheitsdruck\n• Hohe Preise erzielbar (CHF 18-25/500g)',
              icon: Icons.star,
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(
      BuildContext context, String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: BeeTokens.textPrimaer)),
            const SizedBox(height: BeeTokens.sm),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: BeeTokens.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: BeeTokens.textPrimaer)),
                      Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                  color: BeeTokens.textPrimaer))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String wert;
  final String label;
  const _StatBox({required this.wert, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: StatTile(label: label, wert: wert),
    );
  }
}
