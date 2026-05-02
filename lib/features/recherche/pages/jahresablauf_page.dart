import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class JahresablaufPage extends StatelessWidget {
  const JahresablaufPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jahresablauf')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/jahresablauf/detail'),
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
              title: 'Jahresablauf Imkerei',
              subtitle: 'Arosa 1570 m ü.M. · 40-45 Tage Verschiebung vs. Tallagen',
            ),
            const SizedBox(height: 24),
            _buildSeasonOverview(context),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Trachtkalender'),
            const SizedBox(height: 16),
            _buildTrachtkalender(context),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Monatsübersicht'),
            const SizedBox(height: 16),
            _buildMonthCard(context, 'Januar - März',
                'Tiefster Winter / Spätwinter', Icons.ac_unit, [
              'Absolute Winterruhe - keine Eingriffe',
              'Flugloch bei Bedarf freischaufeln',
              'Werkstattarbeit: Rähmchen, Mittelwände',
              'Material für Frühling bestellen',
            ]),
            _buildMonthCard(
                context, 'April', 'Auswinterung', Icons.wb_sunny, [
              'Erste vorsichtige Kontrolle (>12°C)',
              'Futtervorrat prüfen, Notfütterung',
              'Bodentausch / Varroaschieber',
              'Gemülldiagnose (Varroabefall schätzen)',
            ]),
            _buildMonthCard(
                context, 'Mai', 'Aufbauphase', Icons.nature, [
              'Erste Durchsicht (Weiselrichtigkeit)',
              'Drohnenrahmen geben',
              'Wabenhygiene: alte Waben aussortieren',
              'Schied anpassen (Volksausdehnung)',
              'Trachtbeginn: Löwenzahn, Bergahorn',
            ]),
            _buildMonthCard(context, 'Juni', 'Hauptsaison Start',
                Icons.local_florist, [
              'Schwarmkontrolle alle 7-9 Tage!',
              'Honigraum aufsetzen',
              'Ablegerbildung möglich',
              'Haupttracht: Alpenrosen, Bergwiesen',
            ]),
            _buildMonthCard(
                context, 'Juli', 'Honigernte', Icons.emoji_nature, [
              'Honigernte Mitte-Ende Juli',
              'Wassergehalt prüfen (Refraktometer <18%)',
              'Schleudern, Sieben, Abfüllen',
              'Varroa-Behandlung vorbereiten',
            ]),
            _buildMonthCard(context, 'August - September', 'Spätsommer',
                Icons.grain, [
              'Varroa-Sommerbehandlung (Ameisensäure)',
              'Einfütterung: 15-20 kg Sirup pro Volk!',
              'Weiselkontrolle',
              'Schwache Völker vereinigen',
              'Mäuseschutzgitter anbringen',
            ]),
            _buildMonthCard(context, 'Oktober - November', 'Einwinterung',
                Icons.cloud, [
              'Letzte Kontrolle: Futtervorrat wiegen',
              'Winterfestmachung (Sturmsicherung)',
              'Flugloch einengen',
              'Wärmeschied setzen',
            ]),
            _buildMonthCard(context, 'Dezember', 'Winterbehandlung',
                Icons.healing, [
              'Oxalsäure-Behandlung in brutfreier Phase',
              'Idealer Zeitpunkt: 3+ Wochen unter 0°C',
              'Träufelmethode (3.5% Oxalsäurelösung)',
              'Einmalige Anwendung, nicht wiederholen',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonOverview(BuildContext context) {
    final seasons = [
      _Season('Nov - Mär', 'Winterruhe', AppColors.brown100, Icons.ac_unit),
      _Season('Mär - Apr', 'Auswinterung', AppColors.green100, Icons.wb_sunny),
      _Season('Apr - Mai', 'Aufbau', AppColors.green400, Icons.nature),
      _Season(
          'Jun - Jul', 'Hauptsaison', AppColors.amber400, Icons.local_florist),
      _Season('Jul - Sep', 'Spätsommer', AppColors.amber200, Icons.grain),
      _Season('Sep - Okt', 'Einwinterung', AppColors.brown300, Icons.cloud),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phasen-Übersicht',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...seasons.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: Text(
                          s.period,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(s.icon, size: 18, color: AppColors.brown600),
                      const SizedBox(width: 8),
                      Text(s.name),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTrachtkalender(BuildContext context) {
    final tracht = [
      _Tracht('Ende Apr - Mai', 'Weiden, Huflattich, Löwenzahn', 'Erste Pollen'),
      _Tracht('Mai - Jun', 'Löwenzahn, Bergahorn, Heidelbeere', 'Aufbautracht'),
      _Tracht('Jun', 'Bergwiesen, Klee, Glockenblumen', 'Beginn Haupttracht'),
      _Tracht('Mitte Jun - Mitte Jul', 'Alpenrosen, Weidenröschen', 'HAUPTTRACHT'),
      _Tracht('Jul', 'Waldtracht, Disteln, Bergkräuter', 'Wald-/Blütenhonig'),
      _Tracht('Aug - Sep', 'Heidekraut, letzte Bergblüher', 'Läppertracht'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...tracht.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          t.period,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.plants,
                                style: const TextStyle(fontSize: 13)),
                            Text(
                              t.meaning,
                              style: TextStyle(
                                fontSize: 12,
                                color: t.meaning == 'HAUPTTRACHT'
                                    ? AppColors.honey
                                    : AppColors.brown300,
                                fontWeight: t.meaning == 'HAUPTTRACHT'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCard(BuildContext context, String month, String phase,
      IconData icon, List<String> tasks) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.honey),
        title: Text(month, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(phase,
            style: const TextStyle(color: AppColors.brown300, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tasks
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(color: AppColors.brown600)),
                            Expanded(
                              child: Text(t,
                                  style: const TextStyle(
                                      color: AppColors.brown600)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Season {
  final String period;
  final String name;
  final Color color;
  final IconData icon;
  _Season(this.period, this.name, this.color, this.icon);
}

class _Tracht {
  final String period;
  final String plants;
  final String meaning;
  _Tracht(this.period, this.plants, this.meaning);
}
