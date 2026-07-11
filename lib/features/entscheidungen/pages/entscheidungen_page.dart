import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class EntscheidungenPage extends StatelessWidget {
  const EntscheidungenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entscheidungen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Getroffene Entscheidungen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildDecisionCard(
              context,
              title: 'Beutensystem',
              decision: 'Dadant Blatt 10er in Holz',
              details: [
                'Material: Weymouthskiefer, 25-30 mm',
                'Brutraum: 1 Zarge, ungeteilt, mit Schied',
                'Honigraum: Halbzargen (Flachzargen)',
                'Wärmeschied + Styrodur-Isolation für Höhenlage',
              ],
              reason: 'Bio-Honig-Kompatibilität, natürliches Material',
              date: '2. Mai 2026',
              isDone: true,
            ),
            _buildDecisionCard(
              context,
              title: 'Standort',
              decision: 'Maiensäss Tannen 85a, Arosa (1570 m ü.M.)',
              details: [
                'Überwinterung vorerst auf der Alp',
                'Evaluation nach 1-2 Wintern',
              ],
              reason: 'Vorhandene Infrastruktur',
              date: '2. Mai 2026',
              isDone: true,
            ),
            _buildDecisionCard(
              context,
              title: 'Völkerplanung',
              decision: 'Schrittweiser Aufbau',
              details: [
                'Herbst 2026: 1. Volk (Übernahme von Tino Hassler)',
                'Frühling 2027: 2. Volk dazu (für Lorena)',
                'Sommer/Herbst 2027: Nachzucht 1-2 Völker',
                'Bis 2028: Zielgrösse 4 Völker · bis 2030: max. 8 Völker',
              ],
              reason: 'Lernen und wachsen',
              date: '11. Juli 2026',
              isDone: true,
            ),
            _buildDecisionCard(
              context,
              title: 'Bienenrasse',
              decision: 'Buckfast',
              details: [
                'Ableger/Völker als Buckfast',
                'Beratung & Bezug über Tino Hassler (Imker in Maladers)',
                'Sanftmütig, wabenstet, ertragreich – gut für Einsteiger',
              ],
              reason: 'Empfehlung/Gespräch mit Tino Hassler (Maladers)',
              date: '11. Juli 2026',
              isDone: true,
            ),
            _buildDecisionCard(
              context,
              title: 'Lieferant',
              decision: 'Imkerhof Maienfeld + HiveWatch (Stockwaage)',
              details: [
                'Imkerhof Maienfeld: grosses Sortiment, in der Nähe, Dadant Blatt',
                'HiveWatch: Stockwaage (separat, nicht Imkerhof)',
                'Weitere Lieferanten bleiben möglich',
              ],
              reason: 'Grosses Sortiment + Nähe; Qualität vor Preis',
              date: '11. Juli 2026',
              isDone: true,
            ),
            _buildDecisionCard(
              context,
              title: 'Raumkonzept',
              decision: 'Stall + Unterstand nutzen',
              details: [
                'Bienenstand: Bestehender Unterstand',
                'Schleuderraum: Stall OG (leer)',
                'Lager: Stall EG',
              ],
              reason: 'CHF 20-28k Ersparnis durch vorhandene Infrastruktur',
              date: '2. Mai 2026',
              isDone: true,
            ),
            const SizedBox(height: 32),
            Text(
              'Noch offen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildOpenItem(context, 'Stall OG: Masse + Fotos auswerten (Honigverarbeitung)'),
            _buildOpenItem(context, 'Kontakt Ernst Iten (Miel du Ciel)'),
            _buildOpenItem(context, 'Kontakt Bündner Imkerverband'),
            _buildOpenItem(context, 'Bienenstand beim ALT GR registrieren'),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionCard(
    BuildContext context, {
    required String title,
    required String decision,
    required List<String> details,
    required String reason,
    required String date,
    required bool isDone,
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
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isDone ? AppColors.green600 : AppColors.brown300,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Chip(
                  label: Text(date, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.amber50,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                decision,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.green800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppColors.brown600)),
                      Expanded(
                        child: Text(d,
                            style: const TextStyle(color: AppColors.brown600)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Text(
              'Begründung: $reason',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.brown300,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 20, color: AppColors.amber600),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
