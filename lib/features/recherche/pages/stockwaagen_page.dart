import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

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
        backgroundColor: BeeTokens.honig,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Digitale Stockwaagen',
              subtitle: 'Fernüberwachung · Trachtbeobachtung · Schwarmkontrolle',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildKeyFinding(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Systemvergleich'),
            const SizedBox(height: BeeTokens.lg),
            _buildSystemCard(
              context,
              name: 'HiveWatch (Schweiz)',
              rank: '1',
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
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Anforderungen Arosa (1570m)'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Konnektivität: 4G/LTE-M',
              content:
                  'Swisscom hat gute LTE-Abdeckung in Arosa.\nLoRa/Helium: NICHT garantiert auf 1570m!\nWiFi: Unrealistisch am Bienenstand.\n→ Nur 4G-Systeme in Frage.',
              icon: Icons.signal_cellular_alt,
              highlight: true,
            ),
            const InfoCard(
              title: 'Extremwetter',
              content:
                  'Wintertemperaturen bis -25°C\nSchneedruck, UV-Strahlung\nSolar im Winter problematisch (Schnee auf Panel)\n→ Langzeit-Batterie oder geschützter Standort nötig',
              icon: Icons.ac_unit,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Was zeigt eine Stockwaage?'),
            const SizedBox(height: BeeTokens.lg),
            _buildDataCard(context, Icons.trending_up, 'Trachtbeobachtung',
                '+0.5 bis 2 kg/Tag bei Alpenblüte (Mai-Juni)'),
            _buildDataCard(context, Icons.warning_amber, 'Schwarmabgang',
                'Plötzlich >2 kg Gewichtsverlust = Schwarm!'),
            _buildDataCard(context, Icons.thermostat, 'Winterüberwachung',
                '-20 bis -50g/Tag = normaler Futterverbrauch'),
            _buildDataCard(context, Icons.notifications_active, 'Alerts',
                'Push-Benachrichtigung bei Anomalien (Schwarm, Diebstahl, Umkippen)'),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Entscheidung'),
            const SizedBox(height: BeeTokens.lg),
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
          _buildKeyPoint('4G/LTE-M ist die einzig zuverlässige Option in Arosa'),
          _buildKeyPoint(
              'HiveWatch: Schweizer Produkt, bewährt, keine Konfiguration'),
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
          const Icon(Icons.arrow_right, size: 20, color: BeeTokens.honig),
          const SizedBox(width: BeeTokens.xs),
          Expanded(child: Text(text, style: BeeTokens.text)),
        ],
      ),
    );
  }

  Widget _buildSystemCard(
    BuildContext context, {
    required String name,
    required String rank,
    required String subtitle,
    required String price,
    required List<String> features,
    required List<String> cons,
    required String annualCost,
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
                              fontSize: 16,
                              color: BeeTokens.textPrimaer)),
                      Text(subtitle,
                          style: const TextStyle(
                              color: BeeTokens.textSekundaer,
                              fontWeight: FontWeight.w500,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeeTokens.md),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BeeTokens.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: BeeTokens.honigTint,
                    borderRadius: BorderRadius.circular(BeeTokens.sm),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: BeeTokens.textSekundaer),
                  ),
                ),
                const SizedBox(width: BeeTokens.md),
                Text(
                  'Abo: $annualCost',
                  style: const TextStyle(
                      fontSize: 12, color: BeeTokens.textGedaempft),
                ),
              ],
            ),
            const SizedBox(height: BeeTokens.md),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 15, color: BeeSignal.erfolg.text),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: BeeTokens.textPrimaer))),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
            ...cons.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.remove_circle_outline,
                          size: 15, color: BeeSignal.warnung.text),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: BeeTokens.textPrimaer))),
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
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BeeTokens.honigTint,
              borderRadius: BorderRadius.circular(BeeTokens.md),
            ),
            child: Icon(icon, color: BeeTokens.honig, size: 22),
          ),
          const SizedBox(width: BeeTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimaer)),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12, color: BeeTokens.textGedaempft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.honig, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: BeeSignal.erfolg.text, size: 24),
              const SizedBox(width: BeeTokens.sm),
              Text('HiveWatch StarterSet', style: BeeTokens.abschnitt),
            ],
          ),
          const SizedBox(height: BeeTokens.md),
          _buildDecisionRow('Produkt', 'HiveWatch StarterSet'),
          _buildDecisionRow('Preis', 'CHF 694.-'),
          _buildDecisionRow('Konnektivität', '4G/LTE-M (Swisscom)'),
          _buildDecisionRow('Kaufen bei', 'Bienen Meier AG'),
          _buildDecisionRow('Abo', 'CHF 8.-/Monat (96.-/Jahr)'),
          _buildDecisionRow('Phase', '1 (Erstausstattung)'),
          const SizedBox(height: BeeTokens.md),
          const Text(
            'Konfiguration: 1 Waage als Referenz für das produktivste Volk. '
            'Später ggf. Erweiterung auf 2. Waage.',
            style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: BeeTokens.textPrimaer),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: BeeTokens.textGedaempft)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: BeeTokens.textPrimaer))),
        ],
      ),
    );
  }
}
