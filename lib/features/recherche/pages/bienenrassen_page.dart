import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class BienenrassenPage extends StatelessWidget {
  const BienenrassenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienenrassen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/bienenrassen/detail'),
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
              title: 'Bienenrassen für Arosa',
              subtitle: '1570 m · Bio-Honig · Dadant Blatt · 4-5 Völker (ab 2036: max. 8)',
            ),
            const SizedBox(height: 24),
            _buildKeyFinding(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Die drei Optionen'),
            const SizedBox(height: 16),
            _buildRaceCard(
              context,
              name: 'Buckfast',
              rank: '1',
              rankColor: AppColors.amber600,
              subtitle: 'Pragmatisch beste Wahl',
              strengths: [
                'Bewährt im Schanfigg (Miel du Ciel, 30+ Jahre, bis 1770 m)',
                'Bio-Knospe-zertifiziert (bewiesen)',
                'Sehr sanft, geringe Schwarmneigung',
                'Überdurchschnittlicher Honigertrag',
                'VSH-Zucht (Varroa-Toleranz) zukunftsweisend',
                'Belegstation Fideris (Nachbartal)',
              ],
              weaknesses: [
                'F2-Problem bei Standbegattung',
                'Regelmässig neue Königinnen nötig',
              ],
              score: '8.8 / 10',
            ),
            _buildRaceCard(
              context,
              name: 'Dunkle Biene (Mellifera)',
              rank: '2',
              rankColor: AppColors.brown600,
              subtitle: 'Idealistisch / ökologisch beste Wahl',
              strengths: [
                'Perfekt an alpines Klima angepasst (9000 Jahre)',
                'Dunkle Färbung = bessere Wärmeaufnahme',
                'Dosierte Bruttätigkeit (kein Verbrüten)',
                'ProSpecieRara, Slow Food Presidio',
                'Passt ideal zum Bio-Gedanken',
                'Belegstation Valzeina (GR)',
              ],
              weaknesses: [
                'Ca. 20% weniger Honigertrag',
                'Weniger Erfahrung am konkreten Standort',
                'Geringere Verfügbarkeit',
              ],
              score: '7.4 / 10',
            ),
            _buildRaceCard(
              context,
              name: 'Carnica',
              rank: '3',
              rankColor: AppColors.brown300,
              subtitle: 'Nicht empfohlen für 1570 m',
              strengths: [
                'Sanftmütig, grösstes Zuchtnetzwerk',
                'Breiteste Verfügbarkeit',
              ],
              weaknesses: [
                'Zu schnelle Frühjahrsentwicklung (Verbrüten!)',
                'Hoher Schwarmtrieb (aufwändig auf 1570 m)',
                'Nicht optimal für atlantisch-alpines Klima',
              ],
              score: '6.7 / 10',
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Regulierung'),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Freie Rassenwahl im Schanfigg',
              content: 'Kein Schutzgebiet in Arosa/Schanfigg.\nKeine kantonale Vorschrift.\nSchutzgebiete nur in Glarus, Melchtal (OW), Val Müstair (weit weg).',
              icon: Icons.check_circle,
              highlight: true,
            ),
            const InfoCard(
              title: 'Bio-Suisse',
              content: 'Schreibt KEINE bestimmte Rasse vor.\nAnforderung: "An Standort angepasste Bienen".\nBuckfast + Bio-Knospe funktioniert (Miel du Ciel beweist es).',
              icon: Icons.eco,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Referenz: Miel du Ciel'),
            const SizedBox(height: 16),
            _buildReferenceCard(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Nächste Schritte'),
            const SizedBox(height: 16),
            _buildNextStep(context, 'Kontakt Miel du Ciel (Ernst "Aschi" Iten)', 'Erfahrungsaustausch, ev. Ableger-Bezug'),
            _buildNextStep(context, 'Kontakt Bündner Imkerverband', 'Welche Rassen halten Nachbar-Imker im Schanfigg?'),
            _buildNextStep(context, 'Entscheidung Rasse treffen', 'Empfehlung: Buckfast wegen Bewährtheit vor Ort'),
            _buildNextStep(context, 'Grundkurs besuchen', 'Beim Bündner Imkerverband anmelden'),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyFinding(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.amber50, AppColors.green50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.honey, size: 28),
              const SizedBox(width: 12),
              Text(
                'Kernerkenntnisse',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildKeyPoint('Kein Schutzgebiet im Schanfigg → freie Rassenwahl'),
          _buildKeyPoint('Miel du Ciel beweist: Buckfast + Bio + 1770 m funktioniert'),
          _buildKeyPoint('Carnica für 1570 m nicht optimal (Schwarmtrieb, Verbrüten)'),
          _buildKeyPoint('Dunkle Biene theoretisch ideal, aber weniger Praxisbelege vor Ort'),
        ],
      ),
    );
  }

  Widget _buildKeyPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 20, color: AppColors.honeyDark),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceCard(
    BuildContext context, {
    required String name,
    required String rank,
    required Color rankColor,
    required String subtitle,
    required List<String> strengths,
    required List<String> weaknesses,
    required String score,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(rank,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(subtitle,
                          style: TextStyle(
                              color: rankColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: rankColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rankColor.withAlpha(100)),
                  ),
                  child: Text(
                    score,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: rankColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Stärken:',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.green800)),
            const SizedBox(height: 4),
            ...strengths.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.add_circle_outline,
                          size: 16, color: AppColors.green600),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(s, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            const Text('Schwächen:',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.brown600)),
            const SizedBox(height: 4),
            ...weaknesses.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.remove_circle_outline,
                          size: 16, color: AppColors.amber600),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(w, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      color: AppColors.amber50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.honey, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Miel du Ciel -- Bio-Imkerei im Schanfigg',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRefRow('Rasse', 'Buckfast'),
            _buildRefRow('Standorte', '1100 m (Castiel) + 1770 m (Sapün)'),
            _buildRefRow('Völker', 'ca. 30'),
            _buildRefRow('Zertifizierung', 'Bio-Knospe'),
            _buildRefRow('Erfahrung', '30+ Jahre im Schanfigg'),
            _buildRefRow('Strategie', 'Wanderimkerei (Jun-Jul auf Alp)'),
            const SizedBox(height: 8),
            const Text(
              '→ Relevantestes Referenzbeispiel für unser Projekt!',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.honeyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: AppColors.brown600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNextStep(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 20, color: AppColors.amber600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.brown300)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
