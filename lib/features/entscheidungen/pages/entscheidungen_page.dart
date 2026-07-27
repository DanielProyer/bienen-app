import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class EntscheidungenPage extends StatelessWidget {
  const EntscheidungenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entscheidungen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(titel: 'Getroffene Entscheidungen'),
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
              decision: 'Maiensäss, Arosa (1570 m ü.M.)',
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
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(titel: 'Noch offen'),
            _buildOpenItem(
                context, 'Stall OG: Masse + Fotos auswerten (Honigverarbeitung)'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: isDone
                      ? BeeSignal.erfolg.text
                      : BeeTokens.textGedaempft,
                ),
                const SizedBox(width: BeeTokens.md),
                Expanded(child: Text(title, style: BeeTokens.abschnitt)),
                Text(date, style: BeeTokens.gedaempft),
              ],
            ),
            const SizedBox(height: BeeTokens.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BeeTokens.md),
              decoration: BoxDecoration(
                color: BeeSignal.erfolg.flaeche,
                borderRadius: BorderRadius.circular(BeeTokens.rKarte),
              ),
              child: Text(
                decision,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: BeeSignal.erfolg.text,
                ),
              ),
            ),
            const SizedBox(height: BeeTokens.md),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: BeeTokens.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: BeeTokens.textSekundaer)),
                      Expanded(child: Text(d, style: BeeTokens.text)),
                    ],
                  ),
                )),
            const SizedBox(height: BeeTokens.sm),
            Text(
              'Begründung: $reason',
              style: BeeTokens.gedaempft
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenItem(BuildContext context, String text) {
    return AppListTile(
      leading: Icon(Icons.radio_button_unchecked,
          size: 20, color: BeeSignal.warnung.text),
      titel: text,
    );
  }
}
