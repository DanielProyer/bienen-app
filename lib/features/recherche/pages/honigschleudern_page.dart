import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/widgets/info_card.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

class HonigschleuderunPage extends StatelessWidget {
  const HonigschleuderunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Honigschleudern')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/honigschleudern/detail'),
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
              title: 'Motorisierte Honigschleudern',
              subtitle: 'Dadant Blatt · Halbrahmen 435x159mm · 4-8 Völker',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildKeyFinding(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Schleudertypen'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Radialschleuder → EMPFOHLEN',
              content:
                  'Waben wie Speichen im Rad. Kein Wenden nötig!\n12-28 Halbrahmen pro Durchgang.\nIdeal für Dadant Halbrahmen (159mm).\nGeringer Wabenbruch bei kleinen Rahmen.',
              icon: Icons.rotate_right,
              highlight: true,
            ),
            const InfoCard(
              title: 'Selbstwendeschleuder',
              content:
                  'Automatisches Wenden, auch für Brutwaben perfekt.\nAb EUR 2\'500+, 65-80kg schwer.\nFür reine Halbrahmen überdimensioniert.',
              icon: Icons.sync,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Top-Modelle Vergleich'),
            const SizedBox(height: BeeTokens.lg),
            _buildModelCard(
              context,
              rank: '1',
              name: 'Logar 20/8 Radial Motor',
              subtitle: 'Beste Preis-Leistung',
              capacity: '20 Halbrahmen / 4 Brutwaben',
              weight: '39 kg',
              price: 'EUR 1\'570 (~CHF 1\'550)',
              shop: 'honigschleudern.eu',
              pros: [
                '20 HR = komplette Ernte in 1-2 Durchgängen',
                '39 kg = transportabel',
                'Auch für Brutwaben (4 Gitter inkl.)',
                'AISI 304, 0.8mm Wandstärke',
                'Groschopp-Qualitätsmotor'
              ],
              cons: ['Einfacher Motor ohne Programm'],
            ),
            _buildModelCard(
              context,
              rank: '2',
              name: 'Lega TUCANO 20 (GAMMA)',
              subtitle: 'Schweizer Bezug, Unterantrieb',
              capacity: '20 Halbrahmen',
              weight: '~35 kg',
              price: 'CHF 1\'800 (apimat.ch)',
              shop: 'apimat.ch (Schweiz)',
              pros: [
                'Kein Zoll (CH-Händler)',
                'Unterantrieb = freie Beladung oben',
                'WIG-geschweisst',
                '0-460 U/min regelbar'
              ],
              cons: ['CHF 250 teurer als Logar-Import'],
            ),
            _buildModelCard(
              context,
              rank: '3',
              name: 'CFM 18 Flüsterhexe',
              subtitle: 'Extrem leise, Made in Germany',
              capacity: '18 Halbrahmen',
              weight: '~35 kg',
              price: 'EUR 1\'834',
              shop: 'carl-fritz.de',
              pros: [
                'Extrem leise (Direktantrieb 40W)',
                'Made in Germany',
                'Spaltfrei verschweisst',
                'Stufenlos 80-350 U/min'
              ],
              cons: ['2 HR weniger als Logar/Lega', 'Kein Programmautomat'],
            ),
            _buildModelCard(
              context,
              rank: '4',
              name: 'Lega FLAMINGO 28',
              subtitle: 'Maximale Kapazität',
              capacity: '28 Halbrahmen (!!)',
              weight: '~45 kg',
              price: 'CHF 1\'900 (apimat.ch)',
              shop: 'apimat.ch (Schweiz)',
              pros: [
                '28 HR = 8 Völker in EINEM Durchgang',
                'Zukunftssicher für Erweiterung',
                'CH-Bezug ohne Zoll'
              ],
              cons: ['Grösser/schwerer', 'Anfangs überdimensioniert'],
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Hinweise Bergstandort'),
            const SizedBox(height: BeeTokens.lg),
            const InfoCard(
              title: 'Transport nach Arosa',
              content:
                  'Max. 40 kg für eine Person tragbar.\n63cm Kessel passt in jeden Kombi.\n230V Haushaltsstrom ausreichend.\nBei zähflüssigem Berghonig etwas länger schleudern.',
              icon: Icons.terrain,
            ),
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
          _buildKeyPoint(
              'Radialschleuder ist der beste Typ für Dadant Halbrahmen'),
          _buildKeyPoint('20 Halbrahmen-Kapazität reicht für 4-8 Völker'),
          _buildKeyPoint(
              'Logar 20/8: Beste Preis-Leistung (EUR 1\'570, 39 kg)'),
          _buildKeyPoint('Alternative CH-Bezug: Lega TUCANO via apimat.ch'),
          _buildKeyPoint(
              'Gewicht < 40 kg entscheidend für Transport nach Arosa'),
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

  Widget _buildModelCard(
    BuildContext context, {
    required String rank,
    required String name,
    required String subtitle,
    required String capacity,
    required String weight,
    required String price,
    required String shop,
    required List<String> pros,
    required List<String> cons,
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
                        color: BeeTokens.honig, shape: BoxShape.circle),
                    child: Text(rank,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
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
                    ])),
              ],
            ),
            const SizedBox(height: BeeTokens.md),
            Wrap(spacing: BeeTokens.md, runSpacing: BeeTokens.sm, children: [
              _chip(capacity, Icons.grid_view),
              _chip(weight, Icons.fitness_center),
              _chip(price, Icons.euro),
              _chip(shop, Icons.store),
            ]),
            const SizedBox(height: BeeTokens.md),
            ...pros.map((p) =>
                _bulletRow(p, Icons.add_circle_outline, BeeSignal.erfolg.text)),
            ...cons.map((c) => _bulletRow(
                c, Icons.remove_circle_outline, BeeSignal.warnung.text)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.sm, vertical: 4),
      decoration: BoxDecoration(
          color: BeeTokens.honigTint,
          borderRadius: BorderRadius.circular(BeeTokens.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: BeeTokens.textGedaempft),
        const SizedBox(width: BeeTokens.xs),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: BeeTokens.textGedaempft)),
      ]),
    );
  }

  Widget _bulletRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: BeeTokens.textPrimaer))),
      ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle, color: BeeSignal.erfolg.text, size: 24),
          const SizedBox(width: BeeTokens.sm),
          Expanded(
            child: Text('Logar 20/8-Waben Radialschleuder',
                style: BeeTokens.abschnitt),
          ),
        ]),
        const SizedBox(height: BeeTokens.md),
        _decRow('Kapazität', '20 Halbrahmen / 8 Ganzwaben / 4 Brutwaben'),
        _decRow('Motor', '110W / 230V Groschopp'),
        _decRow('Kessel', 'Ø 63cm, Edelstahl AISI 304'),
        _decRow('Gewicht', '39 kg'),
        _decRow('Preis', 'EUR 1\'570 (~CHF 1\'550)'),
        _decRow('Kaufen', 'honigschleudern.eu (Logar Direktshop)'),
        _decRow('Phase', '2 (Honigverarbeitung)'),
      ]),
    );
  }

  Widget _decRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.only(bottom: BeeTokens.xs),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: BeeTokens.textGedaempft))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: BeeTokens.textPrimaer))),
        ]));
  }
}
