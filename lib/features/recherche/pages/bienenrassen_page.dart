import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

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
        backgroundColor: BeeTokens.honig,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Bienenrassen für Arosa',
              subtitle:
                  '1570 m · Bio-Honig · Dadant Blatt · 4-5 Völker (ab 2036: max. 8)',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildKeyFinding(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Die drei Optionen'),
            const SizedBox(height: BeeTokens.lg),
            _buildRaceCard(
              context,
              name: 'Buckfast',
              rank: '1',
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
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Regulierung'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Freie Rassenwahl im Schanfigg',
              content:
                  'Kein Schutzgebiet in Arosa/Schanfigg.\nKeine kantonale Vorschrift.\nSchutzgebiete nur in Glarus, Melchtal (OW), Val Müstair (weit weg).',
              icon: Icons.check_circle,
              highlight: true,
            ),
            const InfoCard(
              title: 'Bio-Suisse',
              content:
                  'Schreibt KEINE bestimmte Rasse vor.\nAnforderung: "An Standort angepasste Bienen".\nBuckfast + Bio-Knospe funktioniert (Miel du Ciel beweist es).',
              icon: Icons.eco,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Referenz: Miel du Ciel'),
            const SizedBox(height: BeeTokens.lg),
            _buildReferenceCard(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Nächste Schritte'),
            const SizedBox(height: BeeTokens.lg),
            _buildNextStep(context, 'Kontakt Miel du Ciel (Ernst "Aschi" Iten)',
                'Erfahrungsaustausch, ev. Ableger-Bezug'),
            _buildNextStep(context, 'Kontakt Bündner Imkerverband',
                'Welche Rassen halten Nachbar-Imker im Schanfigg?'),
            _buildNextStep(context, 'Entscheidung Rasse treffen',
                'Empfehlung: Buckfast wegen Bewährtheit vor Ort'),
            _buildNextStep(context, 'Grundkurs besuchen',
                'Beim Bündner Imkerverband anmelden'),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyFinding(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.honig, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: BeeTokens.honig, size: 28),
              const SizedBox(width: BeeTokens.md),
              Text('Kernerkenntnisse', style: BeeTokens.abschnitt),
            ],
          ),
          const SizedBox(height: BeeTokens.md),
          _buildKeyPoint('Kein Schutzgebiet im Schanfigg → freie Rassenwahl'),
          _buildKeyPoint(
              'Miel du Ciel beweist: Buckfast + Bio + 1770 m funktioniert'),
          _buildKeyPoint(
              'Carnica für 1570 m nicht optimal (Schwarmtrieb, Verbrüten)'),
          _buildKeyPoint(
              'Dunkle Biene theoretisch ideal, aber weniger Praxisbelege vor Ort'),
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
          const Icon(Icons.arrow_right, size: 20, color: BeeTokens.honig),
          const SizedBox(width: BeeTokens.xs),
          Expanded(child: Text(text, style: BeeTokens.text)),
        ],
      ),
    );
  }

  Widget _buildRaceCard(
    BuildContext context, {
    required String name,
    required String rank,
    required String subtitle,
    required List<String> strengths,
    required List<String> weaknesses,
    required String score,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.lg),
      child: AppCard(
        padding: const EdgeInsets.all(BeeTokens.lg),
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
                  child: Text(rank,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: BeeTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: BeeTokens.textPrimaer)),
                      Text(subtitle,
                          style: const TextStyle(
                              color: BeeTokens.textSekundaer,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BeeTokens.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: BeeTokens.honigTint,
                    borderRadius: BorderRadius.circular(BeeTokens.sm),
                  ),
                  child: Text(
                    score,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BeeTokens.textSekundaer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeeTokens.lg),
            Text('Stärken:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: BeeSignal.erfolg.text)),
            const SizedBox(height: BeeTokens.xs),
            ...strengths.map((s) => _bullet(s, Icons.add_circle_outline,
                BeeSignal.erfolg.text)),
            const SizedBox(height: BeeTokens.sm),
            Text('Schwächen:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: BeeSignal.warnung.text)),
            const SizedBox(height: BeeTokens.xs),
            ...weaknesses.map((w) => _bullet(w, Icons.remove_circle_outline,
                BeeSignal.warnung.text)),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: BeeTokens.textPrimaer))),
        ],
      ),
    );
  }

  Widget _buildReferenceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.rand, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: BeeTokens.honig, size: 24),
              const SizedBox(width: BeeTokens.sm),
              Expanded(
                child: Text(
                  'Miel du Ciel -- Bio-Imkerei im Schanfigg',
                  style: BeeTokens.abschnitt,
                ),
              ),
            ],
          ),
          const SizedBox(height: BeeTokens.md),
          _buildRefRow('Rasse', 'Buckfast'),
          _buildRefRow('Standorte', '1100 m (Castiel) + 1770 m (Sapün)'),
          _buildRefRow('Völker', 'ca. 30'),
          _buildRefRow('Zertifizierung', 'Bio-Knospe'),
          _buildRefRow('Erfahrung', '30+ Jahre im Schanfigg'),
          _buildRefRow('Strategie', 'Wanderimkerei (Jun-Jul auf Alp)'),
          const SizedBox(height: BeeTokens.sm),
          const Text(
            '→ Relevantestes Referenzbeispiel für unser Projekt!',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: BeeTokens.textSekundaer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: BeeTokens.textGedaempft)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: BeeTokens.textPrimaer))),
        ],
      ),
    );
  }

  Widget _buildNextStep(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 20, color: BeeTokens.honig),
          const SizedBox(width: BeeTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: BeeTokens.textPrimaer)),
                Text(subtitle, style: BeeTokens.gedaempft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
