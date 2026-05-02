import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class StockwaagenPage extends StatelessWidget {
  const StockwaagenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stockwaagen & Monitoring')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/stockwaagen/detail'),
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
              title: 'Digitale Stockwaagen',
              subtitle: 'Fernüberwachung · Trachtbeobachtung · Schwarmkontrolle',
            ),
            const SizedBox(height: 24),
            _buildKeyFinding(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Systemvergleich'),
            const SizedBox(height: 16),
            _buildSystemCard(
              context,
              name: 'HiveWatch (Schweiz)',
              rank: '1',
              rankColor: AppColors.amber600,
              subtitle: 'Empfehlung für Arosa',
              price: 'CHF 694.-',
              features: [
                '4G/LTE-M (Swisscom) -- garantiert in Arosa',
                'Schweizer Produkt & Support',
                'Temperaturbereich -35°C bis +65°C',
                'Plug & Play, keine Konfiguration',
                'Gewicht + Temperatur + Luftfeuchtigkeit',
              ],
              cons: ['Abo CHF 8.-/Monat', 'Proprietäres System'],
              annualCost: 'CHF 96.-/Jahr',
            ),
            _buildSystemCard(
              context,
              name: 'BroodMinder (USA/EU)',
              rank: '2',
              rankColor: AppColors.green600,
              subtitle: 'Modulares System, 5 Jahre Batterie',
              price: 'EUR 478.- (Waage + Hub)',
              features: [
                'Batterie hält 5 Jahre (!)',
                'Bis 5 Völker mit einem Hub',
                'KI-Schwarmvorhersage',
                'Kostenloser Basis-Tarif',
                'Offene API, Daten gehören dir',
              ],
              cons: ['Hub separat nötig', 'Genauigkeit ±100g', 'Support aus Frankreich'],
              annualCost: '~EUR 90.-/Jahr',
            ),
            _buildSystemCard(
              context,
              name: 'Wolf Waagen ApiGraph 4.0 (DE)',
              rank: '3',
              rankColor: AppColors.brown600,
              subtitle: 'Höchste Präzision',
              price: 'EUR 899.-',
              features: [
                'Auflösung ±10g (!)',
                'Erweiterbar bis 30 Waagen',
                'Beste Web-Datenvisualisierung',
                'Günstigstes Abo',
              ],
              cons: ['Teuerste Anschaffung', 'Import aus DE (Zoll)', 'Kein CH-Support'],
              annualCost: 'EUR 60.70/Jahr',
            ),
            _buildSystemCard(
              context,
              name: 'BeeScales BS01 (Solar)',
              rank: '4',
              rankColor: AppColors.brown300,
              subtitle: 'Bestes Preis-Leistungs-Verhältnis',
              price: 'EUR 520.- (2 Waagen!)',
              features: [
                '2 Waagen zum Preis von einer',
                'Solar-betrieben',
                'Niedrigste 5-Jahres-Kosten',
              ],
              cons: ['Weniger bekannt', 'Support aus Slowenien'],
              annualCost: '~EUR 30.-/Jahr',
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Anforderungen Arosa (1570m)'),
            const SizedBox(height: 16),
            const InfoCard(
              title: 'Konnektivität: 4G/LTE-M',
              content: 'Swisscom hat gute LTE-Abdeckung in Arosa.\nLoRa/Helium: NICHT garantiert auf 1570m!\nWiFi: Unrealistisch am Bienenstand.\n→ Nur 4G-Systeme in Frage.',
              icon: Icons.signal_cellular_alt,
              highlight: true,
            ),
            const InfoCard(
              title: 'Extremwetter',
              content: 'Wintertemperaturen bis -25°C\nSchneedruck, UV-Strahlung\nSolar im Winter problematisch (Schnee auf Panel)\n→ Langzeit-Batterie oder geschützter Standort nötig',
              icon: Icons.ac_unit,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Was zeigt eine Stockwaage?'),
            const SizedBox(height: 16),
            _buildDataCard(context, Icons.trending_up, 'Trachtbeobachtung',
                '+0.5 bis 2 kg/Tag bei Alpenblüte (Mai-Juni)'),
            _buildDataCard(context, Icons.warning_amber, 'Schwarmabgang',
                'Plötzlich >2 kg Gewichtsverlust = Schwarm!'),
            _buildDataCard(context, Icons.thermostat, 'Winterüberwachung',
                '-20 bis -50g/Tag = normaler Futterverbrauch'),
            _buildDataCard(context, Icons.notifications_active, 'Alerts',
                'Push-Benachrichtigung bei Anomalien (Schwarm, Diebstahl, Umkippen)'),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Entscheidung'),
            const SizedBox(height: 16),
            _buildDecisionCard(context),
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
          _buildKeyPoint('4G/LTE-M ist die einzig zuverlässige Option in Arosa'),
          _buildKeyPoint('HiveWatch: Schweizer Produkt, bewährt, keine Konfiguration'),
          _buildKeyPoint('1 Referenzwaage reicht für 4-5 Völker (repräsentativ)'),
          _buildKeyPoint('5-Jahres-Kosten: ca. CHF 1\'174.- (HiveWatch)'),
          _buildKeyPoint('LoRa/Helium und WiFi-Lösungen fallen weg für Arosa'),
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSystemCard(
    BuildContext context, {
    required String name,
    required String rank,
    required Color rankColor,
    required String subtitle,
    required String price,
    required List<String> features,
    required List<String> cons,
    required String annualCost,
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
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle,
                          style: TextStyle(
                              color: rankColor, fontWeight: FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Price row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.honeyDark.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.honeyDark),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Abo: $annualCost',
                  style: const TextStyle(fontSize: 12, color: AppColors.brown600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.add_circle_outline,
                          size: 15, color: AppColors.green600),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
            ...cons.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.remove_circle_outline,
                          size: 15, color: AppColors.amber600),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(c, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(
      BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.honeyDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: AppColors.brown600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(BuildContext context) {
    return Card(
      color: AppColors.amber50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.honey, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.green600, size: 24),
                const SizedBox(width: 8),
                Text(
                  'HiveWatch StarterSet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDecisionRow('Produkt', 'HiveWatch StarterSet'),
            _buildDecisionRow('Preis', 'CHF 694.-'),
            _buildDecisionRow('Konnektivität', '4G/LTE-M (Swisscom)'),
            _buildDecisionRow('Kaufen bei', 'Bienen Meier AG'),
            _buildDecisionRow('Abo', 'CHF 8.-/Monat (96.-/Jahr)'),
            _buildDecisionRow('Phase', '1 (Erstausstattung)'),
            const SizedBox(height: 12),
            const Text(
              'Konfiguration: 1 Waage als Referenz für das produktivste Volk. '
              'Später ggf. Erweiterung auf 2. Waage.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: AppColors.brown600)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
